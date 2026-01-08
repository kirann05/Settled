import SwiftUI
import Contacts
import ContactsUI

/**
 * Contact Management Components
 * 
 * This file contains all contact-related UI components including:
 * - ContactsPermissionManager: Handles contacts permission flow
 * - ContactPicker: Native iOS contact picker wrapper
 * - ParticipantSearchView: Search and selection interface for participants
 * - ContactResultRow: Individual contact display component
 * 
 * Architecture: MVVM pattern with ObservableObject for state management
 * Security: Proper permission handling with user-friendly error messages
 */

// MARK: - Contacts Permission Manager

/**
 * Manages contacts permission state and provides permission request functionality.
 * 
 * Features:
 * - Real-time permission status monitoring
 * - User-friendly permission denial alerts
 * - Automatic permission checking on initialization
 */
class ContactsPermissionManager: ObservableObject {
    @Published var contactsPermissionStatus: CNAuthorizationStatus = .notDetermined
    @Published var showPermissionAlert = false
    @Published var permissionMessage = ""
    
    init() {
        checkContactsPermission()
    }
    
    /// Checks current contacts permission status
    func checkContactsPermission() {
        contactsPermissionStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    /// Requests contacts permission from the user
    func requestContactsPermission() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.contactsPermissionStatus = granted ? .authorized : .denied
                if !granted {
                    self?.showContactsPermissionDeniedAlert()
                }
            }
        }
    }
    
    /// Shows permission denied alert with instructions
    private func showContactsPermissionDeniedAlert() {
        permissionMessage = "Contacts access is required to add participants from your contact list. Please enable contacts access in Settings > Privacy & Security > Contacts > Settled."
        showPermissionAlert = true
    }
    
    /// Computed property to check if contacts can be accessed
    var canAccessContacts: Bool {
        switch contactsPermissionStatus {
        case .authorized:
            return true
        case .notDetermined:
            return true
        default:
            return false
        }
    }
}

// MARK: - Contact Picker Wrapper

/**
 * SwiftUI wrapper for native iOS CNContactPickerViewController.
 * 
 * Features:
 * - Multiple contact selection support
 * - Configurable property fetching
 * - Automatic dismissal handling
 */
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onContactSelected: ([CNContact]) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        
        // Configure what properties we want to fetch
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey
        ]
        
        // Allow multiple selection
        picker.predicateForEnablingContact = NSPredicate(value: true)
        picker.predicateForSelectionOfContact = NSPredicate(value: true)
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPicker
        
        init(_ parent: ContactPicker) {
            self.parent = parent
        }
        
        // Handle single contact selection
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactSelected([contact])
            parent.isPresented = false
        }
        
        // Handle multiple contact selection
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onContactSelected(contacts)
            parent.isPresented = false
        }
        
        // Handle cancellation
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Contact Helper Extensions

/**
 * Convenience extensions for CNContact to provide common functionality.
 */
extension CNContact {
    /// Returns formatted full name or fallback
    var displayName: String {
        let formatter = CNContactFormatter()
        formatter.style = .fullName
        return formatter.string(from: self) ?? "Unknown Contact"
    }
    
    /// Returns primary phone number if available
    var primaryPhoneNumber: String? {
        return phoneNumbers.first?.value.stringValue
    }
    
    /// Returns primary email address if available
    var primaryEmail: String? {
        return emailAddresses.first?.value as String?
    }
}

// MARK: - Participant Search View

/**
 * Advanced search interface for finding and adding bill participants.
 * 
 * Features:
 * - Real-time search filtering
 * - Recent contacts display
 * - New contact creation
 * - Email/phone validation
 * - Compact dropdown interface
 */
struct ParticipantSearchView: View {
    @Binding var searchText: String
    let transactionContacts: [TransactionContact]
    let onContactSelected: (TransactionContact) -> Void
    let onNewContactSubmit: (String) -> Void
    let onCancel: () -> Void
    
    @State private var isSearchFocused = false
    @FocusState private var isTextFieldFocused: Bool
    
    /// Filters contacts based on search text
    var filteredContacts: [TransactionContact] {
        if searchText.isEmpty {
            return Array(transactionContacts.prefix(5)) // Show top 5 recent contacts
        }
        return transactionContacts.filter { contact in
            contact.displayName.lowercased().contains(searchText.lowercased()) ||
            contact.email.lowercased().contains(searchText.lowercased()) ||
            (contact.phoneNumber?.contains(searchText) ?? false)
        }
    }
    
    /// Validates if input is email or phone format
    var isValidEmailOrPhone: Bool {
        searchText.contains("@") || searchText.allSatisfy { char in
            char.isNumber || char == "+" || char == "-" || char == " " || char == "(" || char == ")"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Minimalist underlined search bar (matches Who paid design)
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.adaptiveTextSecondary)
                    .font(.system(size: 12))

                TextField("Add Participants", text: $searchText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.adaptiveTextPrimary)
                    .focused($isTextFieldFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        if !searchText.isEmpty && filteredContacts.isEmpty && isValidEmailOrPhone {
                            print("🟢 [ParticipantSearchView] onSubmit - New contact: \(searchText)")
                            onNewContactSubmit(searchText)
                        }
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.adaptiveTextSecondary)
                            .font(.system(size: 12))
                    }
                } else {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.adaptiveTextSecondary)
                        .font(.system(size: 12))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(isTextFieldFocused ? Color.adaptiveAccentBlue : Color.adaptiveTextSecondary.opacity(0.3))
                        .frame(height: isTextFieldFocused ? 2 : 1)
                }
            )
            .animation(.easeOut(duration: 0.2), value: isTextFieldFocused)
            
            // Compact Dropdown Results
            if !searchText.isEmpty {
                VStack(spacing: 0) {
                    if !filteredContacts.isEmpty {
                        // Show top 3 contacts in dropdown
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredContacts.prefix(3))) { contact in
                                ContactResultRow(contact: contact) {
                                    print("🔵 [ParticipantSearchView] Existing contact selected: \(contact.displayName) (\(contact.email))")
                                    onContactSelected(contact)
                                }
                                .background(Color(.systemBackground))
                                
                                if contact.id != filteredContacts.prefix(3).last?.id {
                                    Divider()
                                        .padding(.leading, 56) // Align with contact text
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    } else if isValidEmailOrPhone {
                        // New contact option in compact dropdown
                        Button(action: {
                            print("🟢 [ParticipantSearchView] New contact submit: \(searchText)")
                            onNewContactSubmit(searchText)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.adaptiveAccentBlue)
                                    .font(.system(size: 20))
                                    .frame(width: 40, height: 40)
                                    .background(Color.adaptiveAccentBlue.opacity(0.1))
                                    .cornerRadius(20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add \(searchText)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("New contact")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 8)
                .zIndex(1000) // Ensure dropdown appears on top
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Contact Result Row

/**
 * Individual contact row component for search results.
 * 
 * Features:
 * - Avatar with initials
 * - Contact name and email display
 * - Transaction count badge
 * - Tap to select functionality
 */
struct ContactResultRow: View {
    let contact: TransactionContact
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(Color.adaptiveAccentBlue.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(contact.displayName.prefix(1).uppercased()))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.adaptiveAccentBlue)
                    )
                
                // Contact Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(contact.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Transaction count
                if contact.totalTransactions > 1 {
                    Text("\(contact.totalTransactions)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}