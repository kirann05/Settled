import SwiftUI
import FirebaseFirestore

/**
 * Bill Edit View - Modal Interface for Editing Bills
 * 
 * Comprehensive bill editing interface with real-time validation and preview.
 * 
 * Features:
 * - Editable bill name with validation
 * - Dynamic item management (add, edit, remove)
 * - Participant management with debt recalculation
 * - Real-time total amount calculation
 * - Async Firebase update with error handling
 * - Change detection and validation
 * 
 * Architecture: MVVM with reactive state management
 * Data Flow: EditSession → BillService → Firebase → Real-time updates
 */

struct BillEditView: View {
    let bill: Bill
    @ObservedObject var editSession: BillEditSession
    @ObservedObject var billManager: BillManager
    @ObservedObject var authViewModel: AuthViewModel
    let onDismiss: () -> Void
    
    @StateObject private var billService = BillService()
    @State private var isUpdating = false
    @State private var updateError: String?
    @State private var showingError = false
    @State private var showingCancelConfirmation = false
    
    // Computed properties
    private var totalAmount: Double {
        editSession.items.reduce(0) { $0 + $1.price }
    }
    
    private var hasValidChanges: Bool {
        editSession.hasChanges && 
        !editSession.billName.isEmpty &&
        !editSession.items.isEmpty &&
        !editSession.participants.isEmpty &&
        !editSession.paidByParticipantId.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Bill Name Section
                    billNameSection
                    
                    // Total Amount Display
                    totalAmountSection
                    
                    // Payer Selection
                    payerSection
                    
                    // Items Management
                    itemsSection
                    
                    // Participants Management
                    participantsSection
                    
                    // Changes Preview
                    if editSession.hasChanges {
                        changesPreviewSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if editSession.hasChanges {
                            showingCancelConfirmation = true
                        } else {
                            onDismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await updateBill()
                        }
                    }
                    .disabled(!hasValidChanges || isUpdating)
                    .fontWeight(.semibold)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(.adaptiveAccentBlue)
                }
            }
        }
        .alert("Discard Changes?", isPresented: $showingCancelConfirmation) {
            Button("Discard", role: .destructive) {
                onDismiss()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .alert("Update Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
                updateError = nil
            }
        } message: {
            Text(updateError ?? "Unknown error occurred")
        }
    }
    
    // MARK: - View Components
    
    private var billNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bill Name")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("Enter bill name", text: $editSession.billName)
                .font(.cerealBody)
                .foregroundColor(.adaptiveTextPrimary)
                .padding(.spacingMD)
                .background(Color.adaptiveDepth1)
                .cornerRadius(.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                        .stroke(Color.adaptiveTextPrimary.opacity(0.2), lineWidth: 1)
                )
                .autocorrectionDisabled()
        }
        .padding(.horizontal)
    }
    
    private var totalAmountSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Total Amount:")
                    .font(.headline)
                Spacer()
                Text("$\(totalAmount, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.adaptiveAccentBlue)
            }
            
            Text("Calculated from \(editSession.items.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.adaptiveAccentBlue.opacity(0.1))
        .cornerRadius(.cornerRadiusButton)
        .padding(.horizontal)
    }
    
    private var payerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who Paid?")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(editSession.participants) { participant in
                    HStack {
                        Button(action: {
                            editSession.paidByParticipantId = participant.id
                        }) {
                            HStack {
                                Circle()
                                    .fill(editSession.paidByParticipantId == participant.id ? Color.adaptiveAccentBlue : Color.gray.opacity(0.3))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: editSession.paidByParticipantId == participant.id ? "checkmark" : "person.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    )
                                
                                Text(participant.displayName)
                                    .fontWeight(.medium)
                                    .foregroundColor(editSession.paidByParticipantId == participant.id ? .blue : .primary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(editSession.paidByParticipantId == participant.id ? Color.adaptiveAccentBlue : Color.clear, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items (\(editSession.items.count))")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // Removed "Add Item" button to maintain OCR validation
            }
            .padding(.horizontal)
            
            if editSession.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cart.badge.plus")
                        .foregroundColor(.gray)
                        .font(.title2)
                    Text("No items yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Add some items to continue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(editSession.items.indices, id: \.self) { index in
                        ItemViewOnlyRow(
                            item: editSession.items[index],
                            participants: editSession.participants
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Participants (\(editSession.participants.count))")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(editSession.participants) { participant in
                    HStack {
                        Circle()
                            .fill(Color.adaptiveAccentBlue)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(participant.displayName)
                                .fontWeight(.medium)
                            Text(participant.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if participant.id == bill.createdBy {
                            Text("Creator")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.adaptiveAccentBlue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            Text("Note: Participant management will be added in future updates")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    
    private var changesPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Changes Preview")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                if editSession.billName != (bill.billName ?? "") {
                    HStack {
                        Text("Bill Name:")
                        Spacer()
                        Text("\"\(bill.billName ?? "")\" → \"\(editSession.billName)\"")
                            .font(.caption)
                            .foregroundColor(.adaptiveAccentBlue)
                    }
                }
                
                if totalAmount != bill.items.reduce(0, { $0 + $1.price }) {
                    HStack {
                        Text("Total Amount:")
                        Spacer()
                        Text("$\(bill.items.reduce(0, { $0 + $1.price }), specifier: "%.2f") → $\(totalAmount, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.adaptiveAccentBlue)
                    }
                }
                
                if editSession.items.count != bill.items.count {
                    HStack {
                        Text("Items Count:")
                        Spacer()
                        Text("\(bill.items.count) → \(editSession.items.count)")
                            .font(.caption)
                            .foregroundColor(.adaptiveAccentBlue)
                    }
                }
            }
            .padding()
            .background(Color.adaptiveAccentBlue.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            if isUpdating {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                    Text("Updating bill...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Actions

    @MainActor
    private func updateBill() async {
        guard hasValidChanges else { return }
        
        isUpdating = true
        updateError = nil
        
        do {
            // Update bill using BillService
            try await billService.updateBill(
                billId: bill.id,
                billName: editSession.billName,
                items: editSession.items,
                participants: editSession.participants,
                paidByParticipantId: editSession.paidByParticipantId,
                currentUserId: authViewModel.user?.uid ?? "",
                currentUserEmail: authViewModel.user?.email ?? "",
                billManager: billManager
            )

            // Wait for Firestore listeners to propagate changes
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // TODO: Send notifications to participants about the update

            onDismiss()
            
        } catch {
            updateError = error.localizedDescription
            showingError = true
        }
        
        isUpdating = false
    }
}

// MARK: - Supporting Views

// ItemViewOnlyRow - Read-only view of items (preserves OCR validation)
struct ItemViewOnlyRow: View {
    let item: BillItem
    let participants: [BillParticipant]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(item.name)
                    .fontWeight(.medium)

                Spacer()

                Text("$\(item.price, specifier: "%.2f")")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            HStack {
                Text("Split among \(item.participantIDs.count) people")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// ItemEditRow - Deprecated, kept for reference only
struct ItemEditRow: View {
    @Binding var item: BillItem
    let participants: [BillParticipant]
    let onDelete: () -> Void

    @State private var showingDetail = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Item name", text: $item.name)
                    .fontWeight(.medium)

                Spacer()

                HStack(spacing: 8) {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("0.00", value: $item.price, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }

            HStack {
                Text("Split among \(item.participantIDs.count) people")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Delete") {
                    onDelete()
                }
                .font(.caption)
                .foregroundColor(.adaptiveAccentRed)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    BillEditView(
        bill: Bill(
            id: "test",
            createdBy: "user1",
            createdByDisplayName: "John Doe",
            createdByEmail: "john@example.com",
            paidBy: "user1",
            paidByDisplayName: "John Doe",
            paidByEmail: "john@example.com",
            billName: "Test Bill",
            totalAmount: 50.0,
            currency: "USD",
            date: Timestamp(),
            createdAt: Timestamp(),
            items: [
                BillItem(name: "Pizza", price: 25.0, participantIDs: ["user1", "user2"]),
                BillItem(name: "Drinks", price: 25.0, participantIDs: ["user1", "user2"])
            ],
            participants: [
                BillParticipant(userID: "user1", displayName: "John Doe", email: "john@example.com"),
                BillParticipant(userID: "user2", displayName: "Jane Smith", email: "jane@example.com")
            ],
            participantIds: ["user1", "user2"],
            isDeleted: false
        ),
        editSession: BillEditSession(),
        billManager: BillManager(),
        authViewModel: AuthViewModel()
    ) {
        // Preview dismiss
    }
}