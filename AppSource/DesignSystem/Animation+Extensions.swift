//
//  Animation+Extensions.swift
//  Settled Design System
//
//  Consistent animation timing and spring curves
//  For smooth, natural UI transitions and micro-interactions
//

import SwiftUI

extension Animation {
    // MARK: - Ease Animations
    // Linear and ease-based timing curves

    /// Smooth ease-out transition - 200ms
    /// Use for: Button hovers, state changes, general transitions
    static let smoothEaseOut = Animation.easeOut(duration: 0.2)

    /// Medium ease-out transition - 300ms
    /// Use for: Modal presentations, sheet transitions
    static let mediumEaseOut = Animation.easeOut(duration: 0.3)

    /// Long ease-out transition - 400ms
    /// Use for: Page transitions, complex animations
    static let longEaseOut = Animation.easeOut(duration: 0.4)

    // MARK: - Spring Animations
    // Natural, physics-based motion curves

    /// Smooth spring - Quick and controlled
    /// Response: 0.3s, Damping: 0.7 (moderate bounce)
    /// Use for: Quick interactions, button presses, toggles
    static let smoothSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Gentle spring - Soft and natural
    /// Response: 0.4s, Damping: 0.8 (subtle bounce)
    /// Use for: Card animations, drag gestures, fluid transitions
    static let gentleSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Bouncy spring - Playful bounce
    /// Response: 0.5s, Damping: 0.6 (noticeable bounce)
    /// Use for: Celebrations, success states, playful interactions
    static let bouncySpring = Animation.spring(response: 0.5, dampingFraction: 0.6)

    /// Snappy spring - Quick and precise
    /// Response: 0.25s, Damping: 0.9 (minimal bounce)
    /// Use for: Precise interactions, picker selections, snap-to-grid
    static let snappySpring = Animation.spring(response: 0.25, dampingFraction: 0.9)

    // MARK: - Specialized Animations
    // Common UI patterns with pre-configured timing

    /// Button press animation
    /// Quick scale-down feedback for button taps
    static let buttonPress = Animation.easeOut(duration: 0.15)

    /// Card flip animation
    /// Medium spring for card rotation and flips
    static let cardFlip = Animation.spring(response: 0.4, dampingFraction: 0.75)

    /// Modal presentation
    /// Smooth ease-in-out for modal/sheet appearance
    static let modalPresent = Animation.easeInOut(duration: 0.35)

    /// Loading pulse
    /// Repeating animation for loading indicators
    static let loadingPulse = Animation
        .easeInOut(duration: 1.0)
        .repeatForever(autoreverses: true)
}

// MARK: - View Modifier Extensions
// Convenient animation application

extension View {
    /// Apply smooth spring animation to view changes
    func withSmoothSpring() -> some View {
        self.animation(.smoothSpring, value: UUID())
    }

    /// Apply gentle spring animation to view changes
    func withGentleSpring() -> some View {
        self.animation(.gentleSpring, value: UUID())
    }

    /// Apply smooth ease-out animation to view changes
    func withSmoothEaseOut() -> some View {
        self.animation(.smoothEaseOut, value: UUID())
    }
}

// MARK: - Usage Examples
/*

 Basic Animation:
 ```
 Button("Tap Me") {
     isPressed.toggle()
 }
 .scaleEffect(isPressed ? 0.95 : 1.0)
 .animation(.buttonPress, value: isPressed)
 ```

 Spring Animation:
 ```
 Circle()
     .offset(y: isExpanded ? 0 : 100)
     .animation(.gentleSpring, value: isExpanded)
 ```

 Modal Presentation:
 ```
 .sheet(isPresented: $showModal) {
     ModalView()
 }
 .animation(.modalPresent, value: showModal)
 ```

 Loading Indicator:
 ```
 Circle()
     .opacity(isLoading ? 0.3 : 1.0)
     .animation(.loadingPulse, value: isLoading)
 ```

 Card Flip:
 ```
 CardView()
     .rotation3DEffect(
         .degrees(isFlipped ? 180 : 0),
         axis: (x: 0, y: 1, z: 0)
     )
     .animation(.cardFlip, value: isFlipped)
 ```

 Combining Animations:
 ```
 VStack {
     Text("Animated")
         .scaleEffect(scale)
         .animation(.smoothSpring, value: scale)

     Rectangle()
         .frame(width: width)
         .animation(.gentleSpring, value: width)
 }
 ```

 Button Hover (macOS/iPadOS):
 ```
 Button("Hover Me") { }
     .scaleEffect(isHovered ? 1.05 : 1.0)
     .animation(.smoothEaseOut, value: isHovered)
     .onHover { hovering in
         isHovered = hovering
     }
 ```

 Transition Animations:
 ```
 if showView {
     ContentView()
         .transition(.scale.combined(with: .opacity))
         .animation(.gentleSpring, value: showView)
 }
 ```

 */
