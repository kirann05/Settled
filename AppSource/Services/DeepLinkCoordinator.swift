//
//  DeepLinkCoordinator.swift
//  Settled
//
//  Centralized deep link handler for navigation from push notifications and external URLs
//

import SwiftUI
import FirebaseFirestore

/**
 # DeepLinkCoordinator

 Centralized deep link handler for navigation from push notifications and external URLs.
 */
class DeepLinkCoordinator: ObservableObject {
    @Published var activeDestination: DeepLinkDestination?
    @Published var pendingDeepLink: URL?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func handle(_ url: URL) {

        guard url.scheme == "settled" else {
            errorMessage = "Invalid link format"
            return
        }

        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }


        switch host {
        case "bill":
            guard let billId = pathComponents.first else {
                errorMessage = "Invalid bill link - missing ID"
                return
            }
            handleBillDeepLink(billId: billId)

        case "home":
            activeDestination = .home

        default:
            errorMessage = "Unknown link destination"
        }
    }

    func clearDestination() {
        activeDestination = nil
        errorMessage = nil
        isLoading = false
    }

    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }

    private func handleBillDeepLink(billId: String) {
        isLoading = true

        Task { @MainActor in
            do {
                let billDoc = try await db.collection("bills").document(billId).getDocument()

                guard billDoc.exists else {
                    isLoading = false
                    errorMessage = "Bill not found or has been deleted"
                    return
                }

                guard let bill = try? billDoc.data(as: Bill.self) else {
                    isLoading = false
                    errorMessage = "Failed to load bill data"
                    return
                }

                isLoading = false
                activeDestination = .billDetail(bill)

            } catch {
                isLoading = false
                errorMessage = "Network error. Please try again."
            }
        }
    }
}

enum DeepLinkDestination: Equatable, Identifiable {
    case billDetail(Bill)
    case home

    var id: String {
        switch self {
        case .billDetail(let bill):
            return "bill_\(bill.id)"
        case .home:
            return "home"
        }
    }

    static func == (lhs: DeepLinkDestination, rhs: DeepLinkDestination) -> Bool {
        lhs.id == rhs.id
    }
}
