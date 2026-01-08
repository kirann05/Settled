import SwiftUI
import Contacts

/**
 * Bill Edit Screen - Full-Page Bill Editing Interface
 *
 * Clean interface matching the Assign Items screen style for comprehensive bill editing.
 *
 * Features:
 * - Bill name editing
 * - Add/remove participants with search
 * - Select who paid the bill
 * - Real-time validation
 * - Save/Cancel with confirmation
 *
 * Architecture: Full-page view with clean layout matching UIAssignScreen
 */

struct BillEditScreen: View {
    let bill: Bill
    @ObservedObject var billManager: BillManager
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var contactsManager: ContactsManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var billService = BillService()
    @State private var billName: String
    @State private var participants: [UIParticipant]
    @State private var paidByParticipantID: String
    @State private var newParticipantName = ""
    @State private var showContactPicker = false
    @State private var showingCancelConfirmation = false
    @State private var isUpdating = false
    @State private var updateError: String?
    @State private var showingError = false
    @StateObject private var contactsPermissionManager = ContactsPermissionManager()

    init(bill: Bill, billManager: BillManager, authViewModel: AuthViewModel, contactsManager: ContactsManager) {
        self.bill = bill
        self.billManager = billManager
        self.authViewModel = authViewModel
        self.contactsManager = contactsManager

        // Initialize state
        _billName = State(initialValue: bill.billName ?? "")
        _paidByParticipantID = State(initialValue: bill.paidBy)

        // Convert BillParticipants to UIParticipants
        let currentUserID = authViewModel.user?.uid ?? ""
        var uiParticipants: [UIParticipant] = []

        for participant in bill.participants {
            let isCurrentUser = participant.id == currentUserID
            uiParticipants.append(UIParticipant(
                id: participant.id,
                name: isCurrentUser ? "You" : participant.displayName,
                color: .blue,  // Will use assignedColor computed property
                photoURL: participant.photoURL
            ))
        }

        _participants = State(initialValue: uiParticipants)
    }

    private var hasChanges: Bool {
        let originalName = bill.billName ?? ""
        let originalParticipantIds = Set(bill.participants.map { $0.id })
        let currentParticipantIds = Set(participants.map { $0.id })

        return billName != originalName ||
               paidByParticipantID != bill.paidBy ||
               originalParticipantIds != currentParticipantIds
    }

    private var canSave: Bool {
        !billName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !participants.isEmpty &&
        !paidByParticipantID.isEmpty &&
        hasChanges
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edit Bill")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Update bill details and participants")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Bill Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Bill Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("*")
                                .foregroundColor(.adaptiveAccentRed)
                                .fontWeight(.bold)
                        }

                        TextField("Enter bill name", text: $billName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    // Who Paid Selection
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Who paid this bill?")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("*")
                                .foregroundColor(.adaptiveAccentRed)
                                .fontWeight(.bold)
                        }

                        Menu {
                            ForEach(participants) { participant in
                                Button(action: {
                                    paidByParticipantID = participant.id
                                }) {
                                    HStack {
                                        if let photoURLString = participant.photoURL,
                                           let photoURL = URL(string: photoURLString) {
                                            AsyncImage(url: photoURL) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 16, height: 16)
                                                    .clipShape(Circle())
                                            } placeholder: {
                                                Circle()
                                                    .fill(participant.color)
                                                    .frame(width: 16, height: 16)
                                            }
                                        } else {
                                            Circle()
                                                .fill(participant.color)
                                                .frame(width: 16, height: 16)
                                        }
                                        Text(participant.name)
                                        if paidByParticipantID == participant.id {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.adaptiveAccentBlue)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if let paidByParticipant = participants.first(where: { $0.id == paidByParticipantID }) {
                                    if let photoURLString = paidByParticipant.photoURL,
                                       let photoURL = URL(string: photoURLString) {
                                        AsyncImage(url: photoURL) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 20, height: 20)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            Circle()
                                                .fill(paidByParticipant.color)
                                                .frame(width: 20, height: 20)
                                        }
                                    } else {
                                        Circle()
                                            .fill(paidByParticipant.color)
                                            .frame(width: 20, height: 20)
                                    }
                                    Text(paidByParticipant.name)
                                        .foregroundColor(.primary)
                                } else {
                                    Text("Select who paid")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)

                    // Participants Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Participants")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal)

                        // Add Participant Search
                        ParticipantSearchView(
                            searchText: $newParticipantName,
                            transactionContacts: contactsManager.transactionContacts,
                            onContactSelected: { contact in
                                handleExistingContactSelected(contact)
                            },
                            onNewContactSubmit: { name in
                                handleAddNewParticipant()
                            },
                            onCancel: {
                                newParticipantName = ""
                            }
                        )
                        .padding(.horizontal)

                        // Current Participants List
                        VStack(spacing: 8) {
                            ForEach(participants) { participant in
                                participantRow(participant)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Action Buttons
                    VStack(spacing: 12) {
                        // Save Button
                        Button(action: {
                            Task {
                                await saveBill()
                            }
                        }) {
                            HStack {
                                if isUpdating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(isUpdating ? "Saving..." : "Save Changes")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSave || isUpdating)

                        // Cancel Button
                        Button("Cancel") {
                            if hasChanges {
                                showingCancelConfirmation = true
                            } else {
                                dismiss()
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(isUpdating)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                .padding(.vertical, 24)
            }
            .navigationBarHidden(true)
        }
        .alert("Discard Changes?", isPresented: $showingCancelConfirmation) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .alert("Update Error", isPresented: $showingError) {
            Button("OK") {
                updateError = nil
            }
        } message: {
            Text(updateError ?? "")
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPicker(isPresented: $showContactPicker) { contacts in
                handleContactsFromPicker(contacts)
            }
        }
    }

    // MARK: - Participant Row

    @ViewBuilder
    private func participantRow(_ participant: UIParticipant) -> some View {
        HStack(spacing: 12) {
            // Profile Picture or Color Circle
            if let photoURLString = participant.photoURL,
               let photoURL = URL(string: photoURLString) {
                AsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(participant.color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.caption)
                        )
                }
            } else {
                Circle()
                    .fill(participant.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                    )
            }

            Text(participant.name)
                .font(.bodyDynamic)
                .fontWeight(.medium)

            Spacer()

            // Remove button (can't remove self or if only 1 participant)
            if participant.name != "You" && participants.count > 1 {
                Button(action: {
                    removeParticipant(participant)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.adaptiveAccentRed.opacity(0.7))
                        .font(.title3)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Participant Management

    private func handleExistingContactSelected(_ contact: TransactionContact) {
        Task {
            // Check if already added
            if participants.contains(where: { p in
                return p.name.lowercased() == contact.displayName.lowercased()
            }) {
                return
            }

            // Add participant using the existing validation flow
            let email = contact.email

            let tempSession = BillSplitSession()
            let (newParticipant, _, _) = await tempSession.addParticipantWithValidation(
                name: contact.displayName,
                email: email,
                phoneNumber: contact.phoneNumber,
                authViewModel: authViewModel,
                contactsManager: contactsManager
            )

            if let newParticipant = newParticipant {
                await MainActor.run {
                    participants.append(newParticipant)
                    newParticipantName = ""
                }
            }
        }
    }

    private func handleAddNewParticipant() {
        let trimmed = newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check if already added
        if participants.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            newParticipantName = ""
            return
        }

        Task {
            // For new participants, we need email validation
            // Show contact picker to get proper contact info
            await MainActor.run {
                showContactPicker = true
            }
        }
    }

    private func handleContactsFromPicker(_ contacts: [CNContact]) {
        Task {
            for contact in contacts {
                let displayName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
                guard !displayName.isEmpty else { continue }

                // Get email
                guard let email = contact.emailAddresses.first?.value as String? else { continue }

                // Get phone number
                let phoneNumber = contact.phoneNumbers.first?.value.stringValue

                let tempSession = BillSplitSession()
                let (newParticipant, _, _) = await tempSession.addParticipantWithValidation(
                    name: displayName,
                    email: email,
                    phoneNumber: phoneNumber,
                    authViewModel: authViewModel,
                    contactsManager: contactsManager
                )

                if let newParticipant = newParticipant {
                    await MainActor.run {
                        if !participants.contains(where: { $0.id == newParticipant.id }) {
                            participants.append(newParticipant)
                        }
                    }
                }
            }

            await MainActor.run {
                newParticipantName = ""
            }
        }
    }

    private func removeParticipant(_ participant: UIParticipant) {
        participants.removeAll { $0.id == participant.id }

        // If removed participant was the payer, reset payer selection
        if paidByParticipantID == participant.id {
            paidByParticipantID = participants.first?.id ?? ""
        }
    }

    // MARK: - Save Bill

    private func saveBill() async {
        await MainActor.run {
            isUpdating = true
        }

        do {
            // Create updated bill participants
            let updatedParticipants = participants.compactMap { participant -> BillParticipant? in
                // Find original participant data or create new
                if let original = bill.participants.first(where: { $0.id == participant.id }) {
                    return original
                } else {
                    // New participant added
                    let contact = contactsManager.transactionContacts.first(where: {
                        $0.displayName.lowercased() == participant.name.lowercased()
                    })

                    return BillParticipant(
                        userID: participant.id,
                        displayName: participant.name == "You" ? (authViewModel.user?.displayName ?? "You") : participant.name,
                        email: contact?.email ?? "",
                        photoURL: participant.photoURL
                    )
                }
            }

            // Update in Firebase using the service method
            try await billService.updateBill(
                billId: bill.id,
                billName: billName.trimmingCharacters(in: .whitespacesAndNewlines),
                items: bill.items,
                participants: updatedParticipants,
                paidByParticipantId: paidByParticipantID,
                currentUserId: authViewModel.user?.uid ?? "",
                currentUserEmail: authViewModel.user?.email ?? "",
                billManager: billManager
            )

            // Update local state
            await MainActor.run {
                isUpdating = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                updateError = error.localizedDescription
                showingError = true
                isUpdating = false
            }
        }
    }
}
