import Foundation
import Contacts
import FirebaseFirestore
import Combine

// MARK: - Contact Integration Types
struct SystemContact {
    let identifier: String
    let firstName: String
    let lastName: String
    let emailAddresses: [String]
    let phoneNumbers: [String]

    var displayName: String {
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var primaryEmail: String? {
        return emailAddresses.first
    }

    var primaryPhone: String? {
        return phoneNumbers.first
    }
}

// MARK: - Contact Selection State
struct ContactSelectionState {
    var selectedContacts: Set<String> = [] // Contact IDs
    var searchText: String = ""
    var isLoading: Bool = false
    var hasPermission: Bool = false
    var errorMessage: String?

    mutating func selectContact(_ contactId: String) {
        selectedContacts.insert(contactId)
    }

    mutating func deselectContact(_ contactId: String) {
        selectedContacts.remove(contactId)
    }

    func isSelected(_ contactId: String) -> Bool {
        return selectedContacts.contains(contactId)
    }
}

// MARK: - Contact Import Sources
enum ContactImportSource {
    case csv
    case json
    case vcard
    case addressBook
}

// MARK: - Contact Error Types
enum ContactError: LocalizedError {
    case permissionDenied
    case contactStoreUnavailable
    case invalidContactData(String)
    case duplicateContact(String)
    case contactNotFound(String)
    case syncFailure(String)
    case importFailure(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Contacts permission is required to add participants"
        case .contactStoreUnavailable:
            return "Contact store is not available on this device"
        case .invalidContactData(let message):
            return "Invalid contact data: \(message)"
        case .duplicateContact(let name):
            return "Contact '\(name)' already exists"
        case .contactNotFound(let id):
            return "Contact not found: \(id)"
        case .syncFailure(let message):
            return "Contact sync failed: \(message)"
        case .importFailure(let message):
            return "Contact import failed: \(message)"
        }
    }
}

// MARK: - Note
/*
 This file contains supporting types for contact management.
 The ContactsManager class implementation is in DataModels.swift.
 */
