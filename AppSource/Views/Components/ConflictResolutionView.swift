import SwiftUI
import FirebaseFirestore

// MARK: - Conflict Resolution UI Components

struct ConflictResolutionView: View {
    let conflict: BillConflict
    let localBill: Bill
    let serverBill: Bill
    @ObservedObject var billManager: BillManager
    @Binding var showingConflict: Bool
    
    @State private var selectedResolution: ConflictResolution?
    @State private var showingComparison = false
    @State private var isResolving = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    conflictHeader
                    conflictDetails
                    resolutionOptions
                    
                    if showingComparison {
                        BillComparisonView(
                            localBill: localBill,
                            serverBill: serverBill,
                            conflictingFields: conflict.conflictingFields
                        )
                    }
                    
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Resolve Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingConflict = false
                    }
                }
            }
        }
    }
    
    private var conflictHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: conflictIcon)
                .font(.system(size: 48))
                .foregroundColor(conflictColor)
            
            Text("Bill Conflict Detected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(conflictDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(conflictColor.opacity(0.1))
        )
    }
    
    private var conflictDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conflict Details")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(
                    title: "Your Version",
                    value: "\(conflict.localVersion)",
                    icon: "person.fill",
                    color: .blue
                )
                
                DetailRow(
                    title: "Server Version",
                    value: "\(conflict.serverVersion)",
                    icon: "server.rack",
                    color: .green
                )
                
                DetailRow(
                    title: "Conflicting Fields",
                    value: conflict.conflictingFields.joined(separator: ", "),
                    icon: "exclamationmark.triangle",
                    color: conflictColor
                )
                
                DetailRow(
                    title: "Detected",
                    value: formatDate(conflict.detectedAt),
                    icon: "clock",
                    color: .secondary
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    private var resolutionOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resolution Options")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(conflict.resolutionOptions, id: \.self) { option in
                    ResolutionOptionButton(
                        option: option,
                        isSelected: selectedResolution == option,
                        onTap: { selectedResolution = option }
                    )
                }
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button("Compare Versions") {
                showingComparison.toggle()
            }
            .buttonStyle(.bordered)
            
            HStack(spacing: 12) {
                if conflict.severity == .low {
                    Button("Dismiss") {
                        billManager.dismissConflict(conflictId: conflict.id)
                        showingConflict = false
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(isResolving ? "Resolving..." : "Resolve") {
                    resolveConflict()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedResolution == nil || isResolving)
            }
        }
    }
    
    private var conflictIcon: String {
        switch conflict.severity {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.octagon"
        case .critical: return "xmark.octagon"
        }
    }
    
    private var conflictColor: Color {
        switch conflict.severity {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .red
        }
    }
    
    private var conflictDescription: String {
        switch conflict.severity {
        case .low:
            return "Minor changes detected. You can safely dismiss or resolve this conflict."
        case .medium:
            return "Conflicting changes were made. Please choose how to proceed."
        case .high:
            return "Significant conflicts require your attention before continuing."
        case .critical:
            return "Critical financial conflicts detected. Please review carefully."
        }
    }
    
    private func formatDate(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp.dateValue())
    }
    
    private func resolveConflict() {
        guard let resolution = selectedResolution else { return }
        
        isResolving = true
        
        Task {
            do {
                try await billManager.resolveConflict(conflictId: conflict.id, resolution: resolution)
                await MainActor.run {
                    showingConflict = false
                }
            } catch {
                await MainActor.run {
                    // Handle error - could show alert
                    isResolving = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
}

struct ResolutionOptionButton: View {
    let option: ConflictResolution
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(optionDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.adaptiveAccentBlue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.adaptiveAccentBlue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var optionDescription: String {
        switch option {
        case .acceptLocal:
            return "Use your changes and overwrite server version"
        case .acceptServer:
            return "Discard your changes and use server version"
        case .merge:
            return "Automatically combine compatible changes"
        case .manual:
            return "Review and manually resolve conflicts"
        case .cancel:
            return "Cancel the operation entirely"
        }
    }
}

struct BillComparisonView: View {
    let localBill: Bill
    let serverBill: Bill
    let conflictingFields: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bill Comparison")
                .font(.headline)
            
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Version")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.adaptiveAccentBlue)
                    
                    BillSummaryCard(bill: localBill, conflictingFields: conflictingFields, isLocal: true)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Server Version")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.adaptiveAccentGreen)
                    
                    BillSummaryCard(bill: serverBill, conflictingFields: conflictingFields, isLocal: false)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct BillSummaryCard: View {
    let bill: Bill
    let conflictingFields: [String]
    let isLocal: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if conflictingFields.contains("billName") {
                FieldRow(label: "Name", value: bill.billName ?? "Untitled", isConflicted: true)
            }
            
            if conflictingFields.contains("totalAmount") {
                FieldRow(label: "Total", value: "$\(bill.totalAmount, specifier: "%.2f")", isConflicted: true)
            }
            
            if conflictingFields.contains("paidBy") {
                FieldRow(label: "Paid By", value: bill.paidByDisplayName, isConflicted: true)
            }
            
            if conflictingFields.contains("currency") {
                FieldRow(label: "Currency", value: bill.currency, isConflicted: true)
            }
            
            if conflictingFields.contains("items") {
                FieldRow(label: "Items", value: "\(bill.items.count) items", isConflicted: true)
            }
            
            if conflictingFields.contains("participants") {
                FieldRow(label: "Participants", value: "\(bill.participants.count) people", isConflicted: true)
            }
            
            FieldRow(label: "Version", value: "\(bill.version)", isConflicted: false)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isLocal ? Color.adaptiveAccentBlue.opacity(0.05) : Color.adaptiveAccentGreen.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isLocal ? Color.adaptiveAccentBlue.opacity(0.3) : Color.adaptiveAccentGreen.opacity(0.3), lineWidth: 1)
        )
    }
}

struct FieldRow: View {
    let label: String
    let value: String
    let isConflicted: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(isConflicted ? .semibold : .regular)
                .foregroundColor(isConflicted ? .primary : .secondary)
        }
        .padding(.horizontal, isConflicted ? 4 : 0)
        .padding(.vertical, isConflicted ? 2 : 0)
        .background(
            isConflicted ? 
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.yellow.opacity(0.2)) : nil
        )
    }
}

// MARK: - Conflict Alert View for Quick Notifications

struct ConflictAlertView: View {
    let conflicts: [BillConflict]
    @ObservedObject var billManager: BillManager
    @State private var selectedConflict: BillConflict?
    @State private var showingResolution = false
    
    var body: some View {
        if !conflicts.isEmpty {
            VStack(spacing: 8) {
                ForEach(conflicts) { conflict in
                    ConflictNotificationCard(
                        conflict: conflict,
                        onTap: {
                            selectedConflict = conflict
                            showingResolution = true
                        },
                        onDismiss: conflict.severity == .low ? {
                            billManager.dismissConflict(conflictId: conflict.id)
                        } : nil
                    )
                }
            }
            .sheet(isPresented: $showingResolution) {
                if let conflict = selectedConflict,
                   let localBill = billManager.optimisticBills.first(where: { $0.id == conflict.operationId }),
                   let serverBill = billManager.confirmedBills.first(where: { $0.id == conflict.operationId }) {
                    ConflictResolutionView(
                        conflict: conflict,
                        localBill: localBill,
                        serverBill: serverBill,
                        billManager: billManager,
                        showingConflict: $showingResolution
                    )
                }
            }
        }
    }
}

struct ConflictNotificationCard: View {
    let conflict: BillConflict
    let onTap: () -> Void
    let onDismiss: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: conflictIcon)
                    .foregroundColor(conflictColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bill Conflict")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Fields: \(conflict.conflictingFields.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(conflictColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(conflictColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var conflictIcon: String {
        switch conflict.severity {
        case .low: return "info.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.octagon.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
    
    private var conflictColor: Color {
        switch conflict.severity {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .red
        }
    }
}