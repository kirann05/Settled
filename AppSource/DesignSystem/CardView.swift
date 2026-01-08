
import SwiftUI

// MARK: - Airbnb-Style Card
/// A clean, distinct card used for listings, summaries, or grouped content
/// rounded corners, soft shadow, white background
struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color.adaptiveSurface)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Flat Card (Bordered)
/// Used for secondary groupings, similar to Airbnb's payment methods or settings rows
struct FlatCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color.adaptiveBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.adaptiveBorder, lineWidth: 1)
            )
            .cornerRadius(12)
    }
}
