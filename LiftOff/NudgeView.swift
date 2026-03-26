// NudgeView.swift
// Unpluq
//
// Created by Fotios Pongas 24.03.2026
// Η κύρια οθόνη — αυτό βλέπει ο χρήστης κάθε φορά
// που σηκώνει το κινητό. Quote + timer + 2 κουμπιά.

//
// Η κύρια οθόνη — quote + timer + 2 κουμπιά.
// Τώρα ενσωματώνει τον PickupDetector!
// NudgeView.swift
// Unpluq

import SwiftUI

struct NudgeView: View {
    @Environment(DataStore.self) var store
    @Environment(PickupDetector.self) var detector
    @Environment(LiveActivityManager.self) var liveActivity
    @Environment(HourlyTracker.self) var hourlyTracker
    @Environment(RewardManager.self) var rewardManager
    
    @State private var currentQuote: String = QuoteBank.random()
    @State private var secondsOnScreen: Int = 0
    @State private var timer: Timer? = nil
    @State private var showingContinueConfirm: Bool = false
    @State private var showNudge: Bool = false
    
    var body: some View {
        ZStack {
            if showNudge {
                nudgeContent
                    .transition(.opacity)
            } else {
                idleContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showNudge)
        .onAppear {
            detector.startMonitoring()
        }
        .onChange(of: detector.pickupDetected) { oldValue, newValue in
            if newValue == true {
                triggerNudge()
            }
        }
    }
    
    private var idleContent: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("LiftOff")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundColor(.secondary)
            
            Text("Monitoring...")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)
            
            if store.todayPickups > 0 {
                Text("\(store.todayPickups) pickups today")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            
            Spacer()
            
            Button(action: {
                triggerNudge()
            }) {
                Text("Test nudge")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 40)
        }
    }
    
    private var nudgeContent: some View {
        VStack(spacing: 24) {
            
            Spacer()
            
            Text(formatTime(secondsOnScreen))
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundColor(.secondary)
                .monospacedDigit()
            
            Text(currentQuote)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {
                    LiftOff()
                }) {
                    Text("LiftOff")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(.systemGray6))
                        )
                }
                
                Button(action: {
                    showingContinueConfirm = true
                }) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                }
            }
            
            if store.currentStreak > 0 {
                Text("\(store.currentStreak)-day streak")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
                .frame(height: 40)
        }
        .alert("Are you sure?", isPresented: $showingContinueConfirm) {
            Button("Yes, I need my phone", role: .destructive) {
                dismissNudge()
            }
            Button("You're right, I'll LiftOff", role: .cancel) {
                LiftOff()
            }
        }
    }
    
    // MARK: - Actions
    
    private func triggerNudge() {
        currentQuote = QuoteBank.random()
        store.recordPickup()
        hourlyTracker.recordPickup()
        secondsOnScreen = 0
        showNudge = true
        startTimer()
        
        liveActivity.update(pickupCount: store.todayPickups)
        
        // Τσέκαρε για rewards μετά από κάθε pickup
        rewardManager.checkForRewards(tracker: hourlyTracker)
    }
    
    private func LiftOff() {
        stopTimer()
        dismissNudge()
    }
    
    private func dismissNudge() {
        stopTimer()
        showNudge = false
        detector.acknowledgePickup()
    }
    
    private func startTimer() {
        timer?.invalidate()
        secondsOnScreen = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            secondsOnScreen += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        store.addUsageTime(seconds: secondsOnScreen)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    NudgeView()
        .environment(DataStore())
        .environment(PickupDetector())
        .environment(LiveActivityManager())
        .environment(HourlyTracker())
        .environment(RewardManager())
}
