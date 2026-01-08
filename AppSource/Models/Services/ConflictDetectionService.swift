import Foundation
import FirebaseFirestore

// Import Bill models for conflict detection types
// Note: These types are defined in Models/Core/BillModels.swift

// MARK: - Conflict Detection Service
final class ConflictDetectionService {
    
    /// Detects conflicts between local and server bill versions
    static func detectConflicts(localBill: Bill, serverBill: Bill, operationId: String) -> BillConflict? {
        // No conflict if versions match
        guard localBill.version != serverBill.version else { return nil }
        
        var conflictingFields: [String] = []
        var severity: ConflictSeverity = .low
        
        // Check for financial conflicts (highest severity)
        if localBill.totalAmount != serverBill.totalAmount {
            conflictingFields.append("totalAmount")
            severity = .critical
        }
        
        if localBill.calculatedTotals != serverBill.calculatedTotals {
            conflictingFields.append("calculatedTotals")
            severity = .critical
        }
        
        if localBill.paidBy != serverBill.paidBy {
            conflictingFields.append("paidBy")
            severity = .high
        }
        
        // Check for item conflicts (medium to high severity)
        if !areItemsCompatible(localItems: localBill.items, serverItems: serverBill.items) {
            conflictingFields.append("items")
            severity = max(severity, .high)
        }
        
        // Check for participant conflicts (medium severity)
        if !areParticipantsCompatible(localParticipants: localBill.participants, serverParticipants: serverBill.participants) {
            conflictingFields.append("participants")
            severity = max(severity, .medium)
        }
        
        // Check for metadata conflicts (low severity)
        if localBill.billName != serverBill.billName {
            conflictingFields.append("billName")
            severity = max(severity, .low)
        }
        
        if localBill.currency != serverBill.currency {
            conflictingFields.append("currency")
            severity = max(severity, .medium)
        }
        
        // Only create conflict if there are actual differences
        guard !conflictingFields.isEmpty else { return nil }
        
        return BillConflict(
            operationId: operationId,
            localVersion: localBill.version,
            serverVersion: serverBill.version,
            conflictingFields: conflictingFields,
            severity: severity
        )
    }
    
    /// Analyzes if a conflict can be automatically resolved
    static func canAutoResolve(conflict: BillConflict) -> Bool {
        // Never auto-resolve critical financial conflicts
        guard conflict.severity != .critical else { return false }
        
        // Auto-resolve simple metadata changes
        let autoResolvableFields = ["billName", "currency"]
        return conflict.conflictingFields.allSatisfy { autoResolvableFields.contains($0) }
    }
    
    /// Automatically resolves compatible conflicts using merge strategy
    static func autoResolveConflict(localBill: Bill, serverBill: Bill, conflict: BillConflict) -> Bill? {
        guard canAutoResolve(conflict: conflict) else { return nil }

        // Note: Bill struct has immutable properties, so we cannot directly merge
        // This function is a placeholder for future implementation when Bill becomes mutable
        // For now, return server version as the safest option

        return serverBill
    }
    
    // MARK: - Private Helpers
    
    private static func areItemsCompatible(localItems: [BillItem], serverItems: [BillItem]) -> Bool {
        // Check if items have significant differences
        guard localItems.count == serverItems.count else { return false }
        
        // Create maps for comparison
        let localMap = Dictionary(uniqueKeysWithValues: localItems.map { ($0.id, $0) })
        let serverMap = Dictionary(uniqueKeysWithValues: serverItems.map { ($0.id, $0) })
        
        // Check for item differences
        for (id, localItem) in localMap {
            guard let serverItem = serverMap[id] else { return false }
            
            // Significant differences that would cause conflicts
            if abs(localItem.price - serverItem.price) > 0.01 { // Penny tolerance
                return false
            }
            
            if localItem.name != serverItem.name {
                return false
            }
            
            if Set(localItem.participantIDs) != Set(serverItem.participantIDs) {
                return false
            }
        }
        
        return true
    }
    
    private static func areParticipantsCompatible(localParticipants: [BillParticipant], serverParticipants: [BillParticipant]) -> Bool {
        // Check if participant lists have significant differences
        guard localParticipants.count == serverParticipants.count else { return false }
        
        let localIds = Set(localParticipants.map { $0.id })
        let serverIds = Set(serverParticipants.map { $0.id })
        
        return localIds == serverIds
    }
}

// MARK: - ConflictSeverity Extensions
extension ConflictSeverity: Comparable {
    public static func < (lhs: ConflictSeverity, rhs: ConflictSeverity) -> Bool {
        let order: [ConflictSeverity] = [.low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
    
    static func max(_ lhs: ConflictSeverity, _ rhs: ConflictSeverity) -> ConflictSeverity {
        return lhs > rhs ? lhs : rhs
    }
}

// MARK: - Conflict Detection Metrics
struct ConflictMetrics {
    let conflictId: String
    let detectionTime: Timestamp
    let severity: ConflictSeverity
    let fieldCount: Int
    let autoResolved: Bool
    let resolutionTime: Timestamp?
    let resolutionStrategy: ConflictResolution?
    
    init(conflict: BillConflict, autoResolved: Bool = false) {
        self.conflictId = conflict.id
        self.detectionTime = conflict.detectedAt
        self.severity = conflict.severity
        self.fieldCount = conflict.conflictingFields.count
        self.autoResolved = autoResolved
        self.resolutionTime = nil
        self.resolutionStrategy = nil
    }
}