// TauntBubbleView.swift
// Picksy
//
// Floating in-app notification bubble for taunts and nudges.
// • Slides in from the top, auto-dismisses after 5 s
// • Swipe UP to dismiss early
// • Tap → navigates to Friends tab

import SwiftUI

// MARK: - Overlay wrapper (drop into any ZStack)

struct TauntBubbleOverlay: View {

    @State private var manager = TauntBubbleManager.shared
    @Environment(TabSelection.self) private var tabSelection

    var body: some View {
        if let msg = manager.pending {
            TauntBubble(message: msg) {
                // On tap — go to Friends tab, then dismiss
                tabSelection.selectedTab = 3
                manager.dismiss()
            } onDismiss: {
                manager.dismiss()
            }
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal:   .move(edge: .top).combined(with: .opacity)
                )
            )
            .id(msg.id)           // re-animate when a new message replaces old one
            .zIndex(999)
        }
    }
}

// MARK: - Individual bubble card

private struct TauntBubble: View {

    let message:   TauntBubbleManager.Message
    let onTap:     () -> Void
    let onDismiss: () -> Void

    // Drag offset for swipe-up-to-dismiss
    @State private var dragY:    CGFloat = 0
    @State private var opacity:  Double  = 1

    // Auto-dismiss timer
    @State private var workItem: DispatchWorkItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)

                Text(message.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)

                Spacer()

                // Small dismiss X
                Button {
                    cancelTimer()
                    dismissWithAnimation()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }

            Text(message.body)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)       // small gap below Dynamic Island / notch
        .offset(y: max(dragY, -300))   // clamp so it doesn't fly infinitely
        .opacity(opacity)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    // Only react to upward drags
                    if value.translation.height < 0 {
                        dragY = value.translation.height
                        opacity = max(0, 1 + (dragY / 80))
                    }
                }
                .onEnded { value in
                    if value.translation.height < -40 {
                        // Committed swipe-up → dismiss
                        cancelTimer()
                        dismissWithAnimation()
                    } else {
                        // Snapped back
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            dragY   = 0
                            opacity = 1
                        }
                    }
                }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            cancelTimer()
            onTap()
        }
        .onAppear {
            scheduleAutoDismiss()
        }
        .onDisappear {
            cancelTimer()
        }
    }

    // MARK: - Helpers

    private func scheduleAutoDismiss() {
        let item = DispatchWorkItem {
            dismissWithAnimation()
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    private func cancelTimer() {
        workItem?.cancel()
        workItem = nil
    }

    private func dismissWithAnimation() {
        withAnimation(.easeIn(duration: 0.25)) {
            opacity = 0
            dragY   = -120
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            onDismiss()
        }
    }
}
