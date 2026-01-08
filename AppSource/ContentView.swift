
import SwiftUI
import FirebaseFirestore

struct ContentView: View {
    @State private var selectedTab = "home"
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var sessionRecoveryManager: SettledRecoveryManager
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @StateObject private var billSplitSession = BillSplitSession()
    @StateObject private var contactsManager = ContactsManager()
    @StateObject private var billManager = BillManager()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.adaptiveBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Content Area
                    TabView(selection: $selectedTab) {
                        ExploreView(session: billSplitSession, billManager: billManager, onCreateNew: startNewBill)
                            .tag("home")
                        
                        // Placeholder for scan - functionality is modal usually
                        Text("Scan")
                            .tag("scan")
                        
                        HistoryView(billManager: billManager, contactsManager: contactsManager)
                            .tag("history")
                        
                        UIProfileScreen()
                            .tag("profile")
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never)) // Custom tab bar means we might want to hide standard?
                    // actually, let's just stick to a custom view switcher for full control
                    
                    // Custom Tab Bar
                    AirbnbTabBar(selectedTab: $selectedTab, onAddTap: startNewBill)
                }
            }
        }
    }

    private func startNewBill() {
        billSplitSession.startNewSession()
        selectedTab = "scan" // In a real app this might present a modal
    }
}

// MARK: - Airbnb-style Tab Bar
struct AirbnbTabBar: View {
    @Binding var selectedTab: String
    let onAddTap: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            // Explore / Home
            TabBarItem(icon: "magnifyingglass", label: "Explore", isSelected: selectedTab == "home") {
                selectedTab = "home"
            }
            
            Spacer()
            
            // Wishlists / History
            TabBarItem(icon: "heart", label: "History", isSelected: selectedTab == "history") {
                selectedTab = "history"
            }
            
            Spacer()
            
            // Trips / Add (Center)
            Button(action: onAddTap) {
                VStack {
                    ZStack {
                        Circle()
                            .fill(Color.brandPrimary)
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.brandPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text("Split")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            }
            .offset(y: -20) // Floating effect
            
            Spacer()
            
            // Inbox / Messages (Placeholder)
            TabBarItem(icon: "message", label: "Inbox", isSelected: selectedTab == "inbox") {
               // selectedTab = "inbox"
            }
            
            Spacer()
            
            // Profile
            TabBarItem(icon: "person.circle", label: "Profile", isSelected: selectedTab == "profile") {
                selectedTab = "profile"
            }
            
            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 34) // Safe area
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? icon + ".fill" : icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .brandPrimary : .textTertiary)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .textPrimary : .textTertiary)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
    }
}

// MARK: - Explore View (Dashboard)
struct ExploreView: View {
    let session: BillSplitSession
    @ObservedObject var billManager: BillManager
    let onCreateNew: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Explore")
                        .font(.cerealHeadline)
                        .foregroundColor(.textPrimary)
                    
                    Text("Track your expenses and splits")
                        .font(.cerealSubheadline)
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Balances Summary
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        BalanceCard(title: "You are owed", amount: 124.50, color: .feedbackSuccess)
                        BalanceCard(title: "You owe", amount: 45.00, color: .feedbackError)
                    }
                    .padding(.horizontal)
                }
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Activity")
                        .font(.cerealTitle2)
                        .padding(.horizontal)
                    
                    VStack(spacing: 24) {
                        ForEach(0..<5) { _ in
                             ActivityRow()
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 100) // Spacing for tab bar
        }
    }
}

struct BalanceCard: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.cerealSubheadline)
                .foregroundColor(.textSecondary)
            
            Text("$\(amount, specifier: "%.2f")")
                .font(.cerealTitle2)
                .foregroundColor(color)
        }
        .padding(20)
        .frame(width: 160)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

struct ActivityRow: View {
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "cart.fill")
                        .foregroundColor(.textSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Grocery Run")
                    .font(.cerealBodyBold)
                    .foregroundColor(.textPrimary)
                Text("Paid by Sarah")
                    .font(.cerealSubheadline)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$42.00")
                    .font(.cerealBodyBold)
                    .foregroundColor(.textPrimary)
                Text("Today")
                    .font(.cerealCaption)
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.vertical, 8)
        .background(Color.white) // clickable area
    }
}

// Note: UIProfileScreen, UIScanScreen, UIAssignScreen, UISummaryScreen, and HistoryView
// are defined in their respective files (UIComponents.swift, HistoryView.swift, ScanView.swift)
