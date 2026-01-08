import SwiftUI
import FirebaseFirestore

/**
 * Bill Detail Screen - Matches Summary Screen Layout
 *
 * Displays bill details in the same structure as Summary screen
 * with Edit and Delete buttons at the bottom.
 */

struct BillDetailScreen: View {
    let bill: Bill
    @ObservedObject var billManager: BillManager
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var contactsManager: ContactsManager
    @Environment(\.dismiss) private var dismiss

    @State private var navigateToEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var expandedPersonIds: Set<String> = []

    // Computed properties
    private var currentBill: Bill {
        if bill.isDeleted {
            return bill
        }
        return billManager.userBills.first(where: { $0.id == bill.id }) ?? bill
    }

    private var isCreator: Bool {
        authViewModel.user?.uid == currentBill.createdBy
    }

    private var billTotal: Double {
        currentBill.items.reduce(0) { $0 + $1.price }
    }

    private var payer: BillParticipant? {
        currentBill.participants.first { $0.id == currentBill.paidBy }
    }

    // Convert Bill to breakdown format for display
    private var breakdownSummaries: [PersonBreakdown] {
        var breakdowns: [PersonBreakdown] = []

        for participant in currentBill.participants {
            let participantItems = currentBill.items.filter { item in
                item.participantIDs.contains(participant.id)
            }.map { item in
                let splitCount = item.participantIDs.count
                let splitPrice = item.price / Double(splitCount)
                return BreakdownItem(name: item.name, price: splitPrice)
            }

            if !participantItems.isEmpty {
                breakdowns.append(PersonBreakdown(
                    id: participant.id,
                    name: participant.displayName,
                    items: participantItems,
                    photoURL: participant.photoURL
                ))
            }
        }

        return breakdowns
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Deleted Bill Banner (if applicable)
                if currentBill.isDeleted {
                    deletedBillBanner
                        .padding(.bottom, .spacingLG)
                }

                // SECTION 1: Bill Info (white background)
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Bill Details")
                        .font(.h3Dynamic)
                        .foregroundColor(.adaptiveTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.paddingScreen)
                        .padding(.bottom, .spacingSM)

                    // Receipt-style Card
                    receiptStyleCard
                        .padding(.horizontal, .paddingScreen)
                        .padding(.bottom, .paddingScreen)
                }
                .background(Color.adaptiveDepth0)

                // SECTION 2: Detailed breakdown with collapsible person cards (light gray background)
                detailedBreakdownSection

                // SECTION 3: Action Buttons (only for creators of active bills)
                if isCreator && !currentBill.isDeleted {
                    actionButtonsSection
                        .background(Color.adaptiveDepth0)
                }
            }
        }
        .background(Color.adaptiveDepth0)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToEdit) {
            BillEditFlow(
                bill: currentBill,
                authViewModel: authViewModel,
                billManager: billManager,
                contactsManager: contactsManager
            )
        }
        .alert("Delete Bill", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteBill()
                }
            }
        } message: {
            Text("Are you sure you want to delete this bill? This action cannot be undone. All participants will be notified and balances will be recalculated.")
        }
        .alert("Delete Error", isPresented: .constant(deleteError != nil)) {
            Button("OK") {
                deleteError = nil
            }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - View Components

    private var deletedBillBanner: some View {
        HStack(spacing: .spacingMD) {
            Image(systemName: "trash.slash.fill")
                .font(.title3)
                .foregroundColor(.white)

            if let deletedByName = currentBill.deletedByDisplayName,
               let deletedAt = currentBill.deletedAt {
                Text("Deleted by \(deletedByName) on \(deletedAt.dateValue().formatted(date: .abbreviated, time: .omitted))")
                    .font(.captionDynamic)
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(.paddingCard)
        .background(Color.adaptiveAccentRed)
        .cornerRadius(.cornerRadiusMedium)
        .padding(.horizontal, .paddingScreen)
    }

    // MARK: - Reusable Card Components

    @ViewBuilder
    private var billInfoCard: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(currentBill.billName ?? "Unnamed Bill")
                .font(.cerealTitle3)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveTextPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(2)

            Text("Created on \(currentBill.date.dateValue().formatted(date: .abbreviated, time: .omitted))")
                .font(.bodyDynamic)
                .foregroundColor(.adaptiveTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spacingMD)
        .background(Color.adaptiveDepth2)
        .cornerRadius(.cornerRadiusMedium)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func infoCard(label: String, icon: String? = nil, iconView: AnyView? = nil, value: String, valueFontSize: CGFloat = 18) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Label with icon
            HStack(spacing: .spacingXS) {
                if let iconView = iconView {
                    iconView
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.adaptiveTextTertiary)
                }

                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(.adaptiveTextSecondary)
            }

            Spacer()

            // Value
            Text(value)
                .font(.system(size: valueFontSize, weight: .semibold))
                .foregroundColor(.adaptiveTextPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(.spacingMD)
        .frame(height: 120)
        .background(Color.adaptiveDepth2)
        .cornerRadius(.cornerRadiusMedium)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var paidByAvatar: some View {
        if let payer = payer, let photoURLString = payer.photoURL, let photoURL = URL(string: photoURLString) {
            AsyncImage(url: photoURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.adaptiveTextSecondary.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.adaptiveTextSecondary)
                            .font(.system(size: 12))
                    )
            }
        } else {
            Circle()
                .fill(Color.adaptiveTextSecondary.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.adaptiveTextSecondary)
                        .font(.system(size: 12))
                )
        }
    }

    @ViewBuilder
    private var receiptStyleCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Adaptive gradient background - custom gradient for receipt card
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(UIColor { traitCollection in
                                traitCollection.userInterfaceStyle == .dark
                                    ? UIColor(red: 0.200, green: 0.200, blue: 0.200, alpha: 1.0)  // Dark: RGB(51,51,51)
                                    : UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)     // Light: RGB(217,217,217) Medium gray
                            }),
                            Color(UIColor { traitCollection in
                                traitCollection.userInterfaceStyle == .dark
                                    ? UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0)  // Dark: RGB(26,26,26)
                                    : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)        // Light: RGB(255,255,255) Pure white
                            })
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.adaptiveTextPrimary.opacity(0.03))
                )

            // Content overlay
            HStack(alignment: .bottom) {
                // Left: Bill name and paid by
                VStack(alignment: .leading, spacing: .spacingSM) {
                    Text(currentBill.billName ?? "Unnamed Bill")
                        .font(.cerealTitle3)
                        .fontWeight(.semibold)
                        .foregroundColor(.adaptiveTextPrimary)
                        .lineLimit(2)

                    // Paid by info
                    HStack(spacing: .spacingXSM) {
                        paidByAvatar

                        Text(payer?.displayName ?? "Unknown")
                            .font(.cerealCaption)
                            .fontWeight(.medium)
                            .foregroundColor(.adaptiveTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Right: Date and Amount
                VStack(alignment: .trailing, spacing: .spacingSM) {
                    Text(currentBill.date.dateValue().formatted(date: .abbreviated, time: .omitted))
                        .font(.cerealCaption)
                        .fontWeight(.medium)
                        .foregroundColor(.adaptiveTextTertiary)

                    Text(String(format: "$%.2f", billTotal))
                        .font(.cerealTitle3)
                        .fontWeight(.bold)
                        .foregroundColor(.adaptiveTextPrimary)
                }
            }
            .padding(.paddingCard)
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color.adaptiveTextPrimary.opacity(0.15), lineWidth: 1)
        )
        .clipped()
    }

    @ViewBuilder
    private var unifiedBillInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: Bill name (left) and Date (right)
            HStack(alignment: .top) {
                Text(currentBill.billName ?? "Unnamed Bill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.adaptiveTextPrimary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Spacer()

                Text(currentBill.date.dateValue().formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 15))
                    .foregroundColor(.adaptiveTextSecondary)
            }
            .padding(.bottom, 20)

            // Bottom row: Payer (left) and Amount (right)
            HStack(alignment: .bottom) {
                HStack(spacing: .spacingXS) {
                    paidByAvatar

                    Text(payer?.displayName ?? "Unknown")
                        .font(.system(size: 15))
                        .foregroundColor(.adaptiveTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(String(format: "$%.2f", billTotal))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.adaptiveTextPrimary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
        }
        .padding(.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveDepth2)
        .cornerRadius(.cornerRadiusMedium)
    }

    @ViewBuilder
    private var paidByAvatarLarge: some View {
        if let payer = payer, let photoURLString = payer.photoURL, let photoURL = URL(string: photoURLString) {
            AsyncImage(url: photoURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.adaptiveTextSecondary.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.adaptiveTextSecondary)
                            .font(.system(size: 24))
                    )
            }
        } else {
            Circle()
                .fill(Color.adaptiveTextSecondary.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.adaptiveTextSecondary)
                        .font(.system(size: 24))
                )
        }
    }

    @ViewBuilder
    private var detailedBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(breakdownSummaries) { person in
                collapsiblePersonCard(for: person)
            }

            // Bottom padding for the section
            Spacer()
                .frame(height: .spacingMD)
        }
    }

    @ViewBuilder
    private func collapsiblePersonCard(for person: PersonBreakdown) -> some View {
        let isExpanded = expandedPersonIds.contains(person.id)
        let totalOwed = person.items.reduce(0.0) { $0 + $1.price }

        VStack(spacing: 0) {
            // Person header with name, amount, and chevron - clickable to expand/collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedPersonIds.remove(person.id)
                    } else {
                        expandedPersonIds.insert(person.id)
                    }
                }
            }) {
                HStack(spacing: .spacingMD) {
                    // Person avatar - profile picture or fallback
                    if let photoURLString = person.photoURL, let photoURL = URL(string: photoURLString) {
                        AsyncImage(url: photoURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.adaptiveTextSecondary.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.adaptiveTextSecondary)
                                        .font(.caption)
                                )
                        }
                    } else {
                        Circle()
                            .fill(Color.adaptiveTextSecondary.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.adaptiveTextSecondary)
                                    .font(.caption)
                            )
                    }

                    // Person name
                    Text(person.name)
                        .font(.cerealBody)
                        .fontWeight(.medium)
                        .foregroundColor(.adaptiveTextPrimary)

                    Spacer()

                    // Total amount
                    Text("$\(totalOwed, specifier: "%.2f")")
                        .font(.cerealBody)
                        .fontWeight(.semibold)
                        .foregroundColor(.adaptiveTextPrimary)
                }
                .padding(.horizontal, .paddingScreen)
                .padding(.vertical, .spacingLG)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content: item list, divider, and subtotal
            if isExpanded {
                VStack(spacing: 0) {
                    // Items
                    ForEach(person.items, id: \.name) { item in
                        HStack {
                            Text(item.name)
                                .font(.bodyDynamic)
                                .foregroundColor(.adaptiveTextSecondary)
                            Spacer()
                            Text("$\(item.price, specifier: "%.2f")")
                                .font(.bodyDynamic)
                                .foregroundColor(.adaptiveTextPrimary)
                        }
                        .padding(.horizontal, .paddingScreen)
                        .padding(.vertical, .spacingMD)
                    }

                    // Bottom padding
                    Spacer()
                        .frame(height: .spacingMD)
                }
            }

            // Horizontal divider between people
            Divider()
                .padding(.horizontal, .paddingScreen)
        }
    }

    private var actionButtonsSection: some View {
        HStack(spacing: .spacingMD) {
            // Delete Button
            Button {
                showingDeleteConfirmation = true
            } label: {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Delete")
                }
            }
            .buttonStyle(DestructiveButtonStyle())
            .disabled(isDeleting)

            // Edit Button
            Button("Edit") {
                navigateToEdit = true
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Actions

    @MainActor
    private func deleteBill() async {
        isDeleting = true
        deleteError = nil

        do {
            let billService = BillService()
            try await billService.deleteBill(
                billId: currentBill.id,
                currentUserId: authViewModel.user?.uid ?? "",
                billManager: billManager
            )

            dismiss()

        } catch {
            deleteError = error.localizedDescription
        }

        isDeleting = false
    }
}

// MARK: - Helper Models

struct PersonBreakdown: Identifiable {
    let id: String
    let name: String
    let items: [BreakdownItem]
    let photoURL: String?
}

struct BreakdownItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
}
