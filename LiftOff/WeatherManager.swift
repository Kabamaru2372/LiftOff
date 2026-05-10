//
//  WeatherManager.swift
//  Picksy
//
//  Created by Fotios Pongas on 23.04.2026
//
//  v1.7 REWRITE: WeatherKit + CoreLocation
//  - Αυτόματη τοποθεσία (When In Use)
//  - Real-time καιρός από Apple WeatherKit
//  - Manual refresh με tap στο temperature pill
//  - Fallback σε Open-Meteo αν WeatherKit αποτύχει
//  - Fixed conditionFromWeatherKit για iOS 26 compatibility
//

import Foundation
import WeatherKit
import CoreLocation

// MARK: - Weather Condition

enum WeatherCondition: String, Codable {
    case sunny
    case partlyCloudy
    case cloudy
    case rainy
    case thunderstorm
    case snow
    case foggy
    case hot
    case cold
    case unknown

    var emoji: String {
        switch self {
        case .sunny:        return "☀️"
        case .partlyCloudy: return "⛅"
        case .cloudy:       return "☁️"
        case .rainy:        return "🌧️"
        case .thunderstorm: return "⛈️"
        case .snow:         return "🌨️"
        case .foggy:        return "🌫️"
        case .hot:          return "🥵"
        case .cold:         return "🥶"
        case .unknown:      return "🌡️"
        }
    }

    var isOutdoorFriendly: Bool {
        switch self {
        case .sunny, .partlyCloudy, .cloudy: return true
        default: return false
        }
    }
}

// MARK: - Weather Data

struct WeatherData: Codable {
    let condition: WeatherCondition
    let temperature: Double
    let cityId: String
    let cityName: String
    let fetchedAt: Date
}

// MARK: - Weather Manager

@Observable
class WeatherManager: NSObject {

    var currentWeather: WeatherData? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    var locationStatus: CLAuthorizationStatus = .notDetermined

    var hasLocationPermission: Bool {
        locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
    }

    private let weatherService = WeatherService.shared
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation? = nil

    private let defaults = UserDefaults.standard
    private let weatherKey = "picksyCachedWeather"
    private let overrideKey = "picksyWeatherOverride"
    private let overrideExpiryKey = "picksyWeatherOverrideExpiry"
    private let refreshInterval: TimeInterval = 10 * 60

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        loadCached()
    }

    // MARK: - Active Condition

    var activeCondition: WeatherCondition {
        if let override = manualOverride, !isOverrideExpired {
            return override
        }
        return currentWeather?.condition ?? .unknown
    }

    // MARK: - Public API

    func fetchWeather(forceRefresh: Bool = false) async {
        if !forceRefresh,
           let cached = currentWeather,
           Date().timeIntervalSince(cached.fetchedAt) < refreshInterval {
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            return
        case .denied, .restricted:
            await fetchWithOpenMeteoFallback()
            return
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        @unknown default:
            await fetchWithOpenMeteoFallback()
        }
    }

    func manualRefresh() async {
        await fetchWeather(forceRefresh: true)
    }

    // MARK: - WeatherKit Fetch

    private func fetchWithWeatherKit(location: CLLocation) async {
        do {
            let weather = try await weatherService.weather(for: location)
            let condition = conditionFromWeatherKit(weather.currentWeather)
            let temp = weather.currentWeather.temperature.converted(to: .celsius).value
            let cityName = await getCityName(from: location)

            let data = WeatherData(
                condition: condition,
                temperature: temp,
                cityId: "current_location",
                cityName: cityName,
                fetchedAt: Date()
            )

            await MainActor.run {
                self.currentWeather = data
                self.isLoading = false
                self.errorMessage = nil
                self.saveCached(data)
            }

            print("[WeatherKit] ✅ \(cityName): \(condition.emoji) \(Int(temp))°C")

        } catch {
            print("[WeatherKit] ❌ \(error.localizedDescription)")
            await fetchWithOpenMeteoFallback(location: location)
        }
    }

    // MARK: - WeatherKit Condition Mapping
    // Χρησιμοποιούμε description string matching για iOS 26 compatibility
    // αντί για specific enum cases που αλλάζουν μεταξύ versions.

    private func conditionFromWeatherKit(_ current: CurrentWeather) -> WeatherCondition {
        let temp = current.temperature.converted(to: .celsius).value

        if temp >= 35 { return .hot }
        if temp <= 0 { return .cold }

        // String-based matching - works across all iOS versions
        let conditionString = current.condition.description.lowercased()

        if conditionString.contains("thunder") || conditionString.contains("storm") {
            return .thunderstorm
        }
        if conditionString.contains("snow") || conditionString.contains("blizzard") ||
           conditionString.contains("sleet") || conditionString.contains("flurr") ||
           conditionString.contains("wintry") || conditionString.contains("frigid") {
            return .snow
        }
        if conditionString.contains("rain") || conditionString.contains("drizzle") ||
           conditionString.contains("shower") || conditionString.contains("freezing") {
            return .rainy
        }
        if conditionString.contains("fog") || conditionString.contains("haze") ||
           conditionString.contains("hazy") || conditionString.contains("smoke") ||
           conditionString.contains("dust") {
            return .foggy
        }
        if conditionString.contains("partly") || conditionString.contains("mostly cloudy") ||
           conditionString.contains("scattered") || conditionString.contains("isolated") {
            return .partlyCloudy
        }
        if conditionString.contains("overcast") ||
           (conditionString.contains("cloudy") && !conditionString.contains("partly")) {
            return .cloudy
        }
        if conditionString.contains("clear") || conditionString.contains("sunny") ||
           conditionString.contains("fair") || conditionString.contains("bright") {
            return .sunny
        }

        // Fallback βάσει basic enum cases (υπάρχουν σε όλες τις iOS versions)
        switch current.condition {
        case .clear, .mostlyClear:
            return .sunny
        case .partlyCloudy, .mostlyCloudy:
            return .partlyCloudy
        default:
            return .unknown
        }
    }

    // MARK: - Open-Meteo Fallback

    private func fetchWithOpenMeteoFallback(location: CLLocation? = nil) async {
        print("[Weather] Using Open-Meteo fallback")

        let lat: Double
        let lon: Double

        if let loc = location ?? currentLocation {
            lat = loc.coordinate.latitude
            lon = loc.coordinate.longitude
        } else {
            // Default: Vaihingen an der Enz
            lat = 48.9287
            lon = 9.0676
        }

        do {
            let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code"
            guard let url = URL(string: urlString) else { throw WeatherError.invalidURL }

            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            let temp = response.current.temperature_2m
            let condition = conditionFromWMO(code: response.current.weather_code, temp: temp)
            let cityName = await getCityName(from: CLLocation(latitude: lat, longitude: lon))

            let weatherData = WeatherData(
                condition: condition,
                temperature: temp,
                cityId: "current_location",
                cityName: cityName,
                fetchedAt: Date()
            )

            await MainActor.run {
                self.currentWeather = weatherData
                self.isLoading = false
                self.saveCached(weatherData)
            }

            print("[OpenMeteo] ✅ Fallback: \(condition.emoji) \(Int(temp))°C")

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private struct OpenMeteoResponse: Codable {
        let current: OpenMeteoCurrent
    }

    private struct OpenMeteoCurrent: Codable {
        let temperature_2m: Double
        let weather_code: Int
    }

    private func conditionFromWMO(code: Int, temp: Double) -> WeatherCondition {
        if temp >= 35 { return .hot }
        if temp <= 0 { return .cold }

        switch code {
        case 0:         return .sunny
        case 1, 2:      return .partlyCloudy
        case 3:         return .cloudy
        case 45, 48:    return .foggy
        case 51...67:   return .rainy
        case 71...77:   return .snow
        case 80...82:   return .rainy
        case 85, 86:    return .snow
        case 95...99:   return .thunderstorm
        default:        return .unknown
        }
    }

    // MARK: - Reverse Geocoding

    private func getCityName(from location: CLLocation) async -> String {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first?.locality
                ?? placemarks.first?.administrativeArea
                ?? "Current Location"
        } catch {
            return "Current Location"
        }
    }

    // MARK: - Manual Override

    func setManualOverride(_ condition: WeatherCondition, duration: TimeInterval = 24 * 3600) {
        defaults.set(condition.rawValue, forKey: overrideKey)
        defaults.set(Date().addingTimeInterval(duration), forKey: overrideExpiryKey)
    }

    func clearManualOverride() {
        defaults.removeObject(forKey: overrideKey)
        defaults.removeObject(forKey: overrideExpiryKey)
    }

    var manualOverride: WeatherCondition? {
        guard let raw = defaults.string(forKey: overrideKey),
              let condition = WeatherCondition(rawValue: raw) else { return nil }
        return condition
    }

    var isOverrideExpired: Bool {
        guard let expiry = defaults.object(forKey: overrideExpiryKey) as? Date else { return true }
        return Date() > expiry
    }

    var hasActiveOverride: Bool {
        manualOverride != nil && !isOverrideExpired
    }

    // MARK: - Cache

    private func saveCached(_ data: WeatherData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: weatherKey)
    }

    private func loadCached() {
        guard let data = defaults.data(forKey: weatherKey),
              let decoded = try? JSONDecoder().decode(WeatherData.self, from: data) else { return }
        currentWeather = decoded
    }

    // MARK: - Compatibility

    var savedCity: City? { nil }

    func selectCity(_ city: City) async {
        await fetchWeather(forceRefresh: true)
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        print("[WeatherKit] 📍 Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        Task {
            await fetchWithWeatherKit(location: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[WeatherKit] ❌ Location error: \(error.localizedDescription)")
        Task {
            await fetchWithOpenMeteoFallback()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.locationStatus = manager.authorizationStatus
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("[WeatherKit] ✅ Location authorized")
            manager.requestLocation()
        case .denied, .restricted:
            print("[WeatherKit] ⚠️ Location denied, using fallback")
            Task { await fetchWithOpenMeteoFallback() }
        default:
            break
        }
    }
}

// MARK: - Errors

enum WeatherError: LocalizedError {
    case invalidURL
    case cityNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:   return "Invalid URL"
        case .cityNotFound: return "City not found"
        }
    }
}

