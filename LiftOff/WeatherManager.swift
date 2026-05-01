//
//  WeatherManager.swift
//  Picksy
//
//  Created by Fotios Pongas on 23.04.2026
//
//  Τραβάει καιρό από το Open-Meteo API (δωρεάν, χωρίς API key).

import Foundation

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
        case .rainy, .thunderstorm, .snow, .foggy, .hot, .cold: return false
        case .unknown: return true
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
class WeatherManager {

    var currentWeather: WeatherData? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let defaults = UserDefaults.standard
    private let weatherKey = "picksyCachedWeather"
    private let cityIdKey = "picksyWeatherCityId"
    private let overrideKey = "picksyWeatherOverride"
    private let overrideExpiryKey = "picksyWeatherOverrideExpiry"

    private let refreshInterval: TimeInterval = 10 * 60 // 30 λεπτά

    init() {
        loadCached()
    }

    // MARK: - Public API

    /// Το id της επιλεγμένης πόλης
    var savedCityId: String {
        get { defaults.string(forKey: cityIdKey) ?? "" }
        set { defaults.set(newValue, forKey: cityIdKey) }
    }

    /// Η City object που έχει επιλέξει ο χρήστης
    var savedCity: City? {
        guard !savedCityId.isEmpty else { return nil }
        return CitiesDatabase.find(id: savedCityId)
    }

    /// Επιστρέφει το τρέχον condition (με override priority)
    var activeCondition: WeatherCondition {
        if let override = manualOverride, !isOverrideExpired {
            return override
        }
        return currentWeather?.condition ?? .unknown
    }

    var hasCity: Bool {
        savedCity != nil
    }

    // MARK: - Set city and fetch

    /// Καλείται όταν ο χρήστης επιλέγει νέα πόλη από το picker
    func selectCity(_ city: City) async {
        // Clear τα παλιά δεδομένα καιρού (fix για το bug!)
        await MainActor.run {
            self.currentWeather = nil
            self.errorMessage = nil
            self.savedCityId = city.id
        }

        await fetchWeather(forceRefresh: true)
    }

    /// Τραβάει τον καιρό για την αποθηκευμένη πόλη
    func fetchWeather(forceRefresh: Bool = false) async {
        guard let city = savedCity else { return }

        // Αν έχουμε πρόσφατα δεδομένα για ΑΥΤΗ την πόλη, μην ξανατραβήξουμε
        if !forceRefresh,
           let cached = currentWeather,
           cached.cityId == city.id,
           Date().timeIntervalSince(cached.fetchedAt) < refreshInterval {
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // Βήμα 1: Geocoding — city name → συντεταγμένες
            let coords = try await getCoordinates(for: city)

            // Βήμα 2: Weather request
            let weather = try await getWeather(lat: coords.lat, lon: coords.lon)

            let data = WeatherData(
                condition: weather.condition,
                temperature: weather.temp,
                cityId: city.id,
                cityName: city.nameEN,
                fetchedAt: Date()
            )

            await MainActor.run {
                self.currentWeather = data
                self.isLoading = false
                self.saveCached(data)
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Manual Override

    func setManualOverride(_ condition: WeatherCondition, duration: TimeInterval = 24 * 3600) {
        let expiry = Date().addingTimeInterval(duration)
        defaults.set(condition.rawValue, forKey: overrideKey)
        defaults.set(expiry, forKey: overrideExpiryKey)
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
        return manualOverride != nil && !isOverrideExpired
    }

    // MARK: - Geocoding (χρησιμοποιούμε το English name της πόλης)

    private struct GeocodingResponse: Codable {
        let results: [GeoResult]?
    }

    private struct GeoResult: Codable {
        let latitude: Double
        let longitude: Double
    }

    private func getCoordinates(for city: City) async throws -> (lat: Double, lon: Double) {
        let encoded = city.nameEN.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city.nameEN
        let urlString = "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=5&language=en&format=json"

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GeocodingResponse.self, from: data)

        guard let first = response.results?.first else {
            throw WeatherError.cityNotFound
        }

        return (first.latitude, first.longitude)
    }

    // MARK: - Weather API

    private struct WeatherResponse: Codable {
        let current: CurrentWeather
    }

    private struct CurrentWeather: Codable {
        let temperature_2m: Double
        let weather_code: Int
    }

    private func getWeather(lat: Double, lon: Double) async throws -> (condition: WeatherCondition, temp: Double) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code"

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(WeatherResponse.self, from: data)

        let temp = response.current.temperature_2m
        let condition = conditionFrom(code: response.current.weather_code, temp: temp)

        return (condition, temp)
    }

    /// Μετατρέπει τον WMO weather code σε WeatherCondition
    private func conditionFrom(code: Int, temp: Double) -> WeatherCondition {
        // Extreme temperature priority
        if temp >= 30 { return .hot }
        if temp <= 5 { return .cold }

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

    // MARK: - Cache

    private func saveCached(_ data: WeatherData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: weatherKey)
    }

    private func loadCached() {
        guard let data = defaults.data(forKey: weatherKey),
              let decoded = try? JSONDecoder().decode(WeatherData.self, from: data) else { return }

        // Φόρτωσε μόνο αν ανήκει στην τρέχουσα πόλη
        if decoded.cityId == savedCityId {
            currentWeather = decoded
        }
    }
}

// MARK: - Errors

enum WeatherError: LocalizedError {
    case invalidURL
    case cityNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .cityNotFound: return "City not found"
        }
    }
}

