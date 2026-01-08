import Foundation
import SwiftUI

/**
 * Bill Edit Session - Shared state management for bill editing
 *
 * Manages editable state for bill modifications with change tracking.
 * Used by both BillDetailScreen and HistoryBillDetailView.
 *
 * Features:
 * - Published properties for reactive UI updates
 * - Change detection comparing against original bill
 * - Bill loading from existing Bill objects
 *
 * Architecture: ObservableObject for SwiftUI state management
 */
class BillEditSession: ObservableObject {
    @Published var billName: String = ""
    @Published var items: [BillItem] = []
    @Published var participants: [BillParticipant] = []
    @Published var paidByParticipantId: String = ""

    private var originalBill: Bill?

    func loadBill(_ bill: Bill) {
        originalBill = bill
        billName = bill.billName ?? ""
        items = bill.items
        participants = bill.participants
        paidByParticipantId = bill.paidBy
    }

    var hasChanges: Bool {
        guard let original = originalBill else { return false }

        return billName != (original.billName ?? "") ||
               items != original.items ||
               participants != original.participants ||
               paidByParticipantId != original.paidBy
    }
}
