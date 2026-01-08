
import SwiftUI
import GoogleSignInSwift

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogo = false
    @State private var showHeading = false
    @State private var showSubtitle = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            // New clean background
            Color.adaptiveBackground.ignoresSafeArea()
            
            VStack {
                // Top marketing content
                Spacer()
                
                VStack(spacing: 24) {
                    // Modern minimalist logo with animation
                    ZStack {
                        Circle()
                            .fill(Color.brandPrimary)
                            .frame(width: 80, height: 80)

                        Image(systemName: "dollarsign")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.shadowMedium, radius: 8, x: 0, y: 4)
                    .scaleEffect(showLogo ? 1.0 : 0.5)
                    .opacity(showLogo ? 1.0 : 0.0)

                    VStack(spacing: 8) {
                        Text("Welcome to Settled")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .opacity(showHeading ? 1.0 : 0.0)
                            .offset(y: showHeading ? 0 : 20)

                        Text("The easiest way to split bills\nwith your friends and family.")
                            .font(.system(size: 17))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .opacity(showSubtitle ? 1.0 : 0.0)
                            .offset(y: showSubtitle ? 0 : 20)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Bottom Authentication Action Area with slide-up animation
                VStack(spacing: 24) {
                    if authViewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color.brandPrimary)
                    } else if showButton {
                        // Airbnb-style prominent button
                        Button(action: {
                            Task {
                                await authViewModel.signInWithGoogle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 20))
                                Text("Continue with Google")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        // Terms (larger and more readable)
                        Text("By tapping Continue, you agree to our Terms of Service and Privacy Policy.")
                            .font(.system(size: 13))
                            .foregroundColor(.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    if !authViewModel.errorMessage.isEmpty {
                        Text(authViewModel.errorMessage)
                            .font(.cerealSubheadline)
                            .foregroundColor(.feedbackError)
                            .padding()
                            .background(Color.feedbackError.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 60)
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            // Staggered animations
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showLogo = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                showHeading = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5)) {
                showSubtitle = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.7)) {
                showButton = true
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
