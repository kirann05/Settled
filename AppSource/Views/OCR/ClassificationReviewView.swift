//
//  ClassificationReviewView.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import SwiftUI

/// Review and correct receipt item classifications
struct ClassificationReviewView: View {
    @Binding var classifiedReceipt: ClassifiedReceipt
    @State private var showingCategoryPicker = false
    @State private var selectedItemForEdit: ClassifiedReceiptItem?
    @State private var editedItems: Set<String> = []

    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with validation status
                validationStatusHeader

                // Validation issues (if any)
                if !classifiedReceipt.validationIssues.isEmpty {
                    validationIssuesSection
                }

                // Food Items
                if !classifiedReceipt.foodItems.isEmpty {
                    itemSection(
                        title: "Food Items",
                        icon: "fork.knife",
                        items: classifiedReceipt.foodItems
                    )
                }

                // Tax
                if let tax = classifiedReceipt.tax {
                    singleItemSection(
                        title: "Tax",
                        icon: "percent",
                        item: tax
                    )
                }

                // Tip
                if let tip = classifiedReceipt.tip {
                    singleItemSection(
                        title: "Tip",
                        icon: "dollarsign.circle",
                        item: tip
                    )
                }

                // Gratuity
                if let gratuity = classifiedReceipt.gratuity {
                    singleItemSection(
                        title: "Gratuity (Auto-added)",
                        icon: "percent.circle",
                        item: gratuity
                    )
                }

                // Discounts
                if !classifiedReceipt.discounts.isEmpty {
                    itemSection(
                        title: "Discounts",
                        icon: "tag.fill",
                        items: classifiedReceipt.discounts
                    )
                }

                // Other Charges
                if !classifiedReceipt.otherCharges.isEmpty {
                    itemSection(
                        title: "Other Charges",
                        icon: "plus.circle",
                        items: classifiedReceipt.otherCharges
                    )
                }

                // Unknown Items (needs review)
                if !classifiedReceipt.unknownItems.isEmpty {
                    itemSection(
                        title: "Unknown Items (Needs Review)",
                        icon: "questionmark.circle",
                        items: classifiedReceipt.unknownItems,
                        isWarning: true
                    )
                }

                // Subtotal & Total Summary
                summarySection

                // Complete Button
                Button(action: onComplete) {
                    HStack {
                        Image(systemName: "arrow.right")
                        Text("Continue")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canContinue ? Color.blue : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!canContinue)
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Review Classification")
        .sheet(item: $selectedItemForEdit) { item in
            CategoryPickerView(
                item: item,
                onSave: { updatedItem in
                    updateItemCategory(updatedItem)
                }
            )
        }
    }

    // MARK: - Validation Status Header

    private var validationStatusHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: classifiedReceipt.validationStatus.icon)
                .font(.title2)
                .foregroundColor(classifiedReceipt.validationStatus.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(classifiedReceipt.validationStatus.displayName)
                    .font(.headline)

                Text("Confidence: \(Int(classifiedReceipt.totalConfidence * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(classifiedReceipt.validationStatus.color.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Validation Issues Section

    private var validationIssuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Validation Issues", systemImage: "exclamationmark.triangle")
                .font(.headline)

            ForEach(Array(classifiedReceipt.validationIssues.enumerated()), id: \.offset) { index, issue in
                HStack(spacing: 8) {
                    Image(systemName: issue.severity.icon)
                        .foregroundColor(issue.severity.color)

                    Text(issue.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Item Sections

    private func itemSection(title: String, icon: String, items: [ClassifiedReceiptItem], isWarning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(isWarning ? .orange : .primary)

            ForEach(items) { item in
                itemRow(item)
            }
        }
    }

    private func singleItemSection(title: String, icon: String, item: ClassifiedReceiptItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            itemRow(item)
        }
    }

    private func itemRow(_ item: ClassifiedReceiptItem) -> some View {
        Button(action: {
            selectedItemForEdit = item
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        // Confidence badge
                        confidenceBadge(item.confidenceLevel)

                        // Classification method
                        Text(item.classificationMethod.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Edited indicator
                        if editedItems.contains(item.id) {
                            Label("Edited", systemImage: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }

                Spacer()

                Text("$\(String(format: "%.2f", item.price))")
                    .font(.headline)
                    .foregroundColor(.primary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.needsReview ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(item.needsReview ? Color.orange : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func confidenceBadge(_ level: ConfidenceLevel) -> some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
            Text(level.displayName)
        }
        .font(.caption)
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(level.color)
        .cornerRadius(4)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(spacing: 12) {
            Divider()

            if let subtotal = classifiedReceipt.subtotal {
                summaryRow(label: "Subtotal", amount: subtotal.price, isBold: false)
            } else {
                summaryRow(label: "Food Items Total", amount: classifiedReceipt.foodItemsSum(), isBold: false)
            }

            if let tax = classifiedReceipt.tax {
                summaryRow(label: "Tax", amount: tax.price, isBold: false)
            }

            if let tip = classifiedReceipt.tip {
                summaryRow(label: "Tip", amount: tip.price, isBold: false)
            }

            if let gratuity = classifiedReceipt.gratuity {
                summaryRow(label: "Gratuity", amount: gratuity.price, isBold: false)
            }

            if !classifiedReceipt.otherCharges.isEmpty {
                let otherTotal = classifiedReceipt.otherCharges.reduce(0.0) { $0 + $1.price }
                summaryRow(label: "Other Charges", amount: otherTotal, isBold: false)
            }

            if !classifiedReceipt.discounts.isEmpty {
                let discountTotal = classifiedReceipt.discounts.reduce(0.0) { $0 + abs($1.price) }
                summaryRow(label: "Discounts", amount: -discountTotal, isBold: false, isDiscount: true)
            }

            Divider()

            if let total = classifiedReceipt.total {
                summaryRow(label: "Total", amount: total.price, isBold: true)
            } else {
                summaryRow(label: "Total", amount: classifiedReceipt.totalCharges(), isBold: true)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }

    private func summaryRow(label: String, amount: Double, isBold: Bool, isDiscount: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? .headline : .body)
                .foregroundColor(isDiscount ? .red : .primary)

            Spacer()

            Text("$\(String(format: "%.2f", amount))")
                .font(isBold ? .headline : .body)
                .foregroundColor(isDiscount ? .red : .primary)
        }
    }

    // MARK: - Helpers

    private var canContinue: Bool {
        // Allow continue if:
        // 1. No unknown items, OR
        // 2. All items have been reviewed/edited
        classifiedReceipt.unknownItems.isEmpty ||
        classifiedReceipt.unknownItems.allSatisfy { editedItems.contains($0.id) }
    }

    private func updateItemCategory(_ updatedItem: ClassifiedReceiptItem) {
        // Mark as edited
        editedItems.insert(updatedItem.id)

        // Update the classified receipt
        var updatedReceipt = classifiedReceipt

        // Remove from all categories
        updatedReceipt = ClassifiedReceipt(
            foodItems: updatedReceipt.foodItems.filter { $0.id != updatedItem.id },
            tax: updatedReceipt.tax?.id == updatedItem.id ? nil : updatedReceipt.tax,
            tip: updatedReceipt.tip?.id == updatedItem.id ? nil : updatedReceipt.tip,
            gratuity: updatedReceipt.gratuity?.id == updatedItem.id ? nil : updatedReceipt.gratuity,
            subtotal: updatedReceipt.subtotal?.id == updatedItem.id ? nil : updatedReceipt.subtotal,
            total: updatedReceipt.total?.id == updatedItem.id ? nil : updatedReceipt.total,
            discounts: updatedReceipt.discounts.filter { $0.id != updatedItem.id },
            otherCharges: updatedReceipt.otherCharges.filter { $0.id != updatedItem.id },
            unknownItems: updatedReceipt.unknownItems.filter { $0.id != updatedItem.id },
            totalConfidence: updatedReceipt.totalConfidence,
            validationStatus: updatedReceipt.validationStatus,
            validationIssues: updatedReceipt.validationIssues
        )

        // Add to appropriate category
        switch updatedItem.category {
        case .food:
            var foodItems = updatedReceipt.foodItems
            foodItems.append(updatedItem)
            updatedReceipt = ClassifiedReceipt(
                foodItems: foodItems.sorted { $0.position < $1.position },
                tax: updatedReceipt.tax,
                tip: updatedReceipt.tip,
                gratuity: updatedReceipt.gratuity,
                subtotal: updatedReceipt.subtotal,
                total: updatedReceipt.total,
                discounts: updatedReceipt.discounts,
                otherCharges: updatedReceipt.otherCharges,
                unknownItems: updatedReceipt.unknownItems,
                totalConfidence: updatedReceipt.totalConfidence,
                validationStatus: updatedReceipt.validationStatus,
                validationIssues: updatedReceipt.validationIssues
            )
        case .tax:
            updatedReceipt = ClassifiedReceipt(
                foodItems: updatedReceipt.foodItems,
                tax: updatedItem,
                tip: updatedReceipt.tip,
                gratuity: updatedReceipt.gratuity,
                subtotal: updatedReceipt.subtotal,
                total: updatedReceipt.total,
                discounts: updatedReceipt.discounts,
                otherCharges: updatedReceipt.otherCharges,
                unknownItems: updatedReceipt.unknownItems,
                totalConfidence: updatedReceipt.totalConfidence,
                validationStatus: updatedReceipt.validationStatus,
                validationIssues: updatedReceipt.validationIssues
            )
        case .tip:
            updatedReceipt = ClassifiedReceipt(
                foodItems: updatedReceipt.foodItems,
                tax: updatedReceipt.tax,
                tip: updatedItem,
                gratuity: updatedReceipt.gratuity,
                subtotal: updatedReceipt.subtotal,
                total: updatedReceipt.total,
                discounts: updatedReceipt.discounts,
                otherCharges: updatedReceipt.otherCharges,
                unknownItems: updatedReceipt.unknownItems,
                totalConfidence: updatedReceipt.totalConfidence,
                validationStatus: updatedReceipt.validationStatus,
                validationIssues: updatedReceipt.validationIssues
            )
        case .gratuity:
            updatedReceipt = ClassifiedReceipt(
                foodItems: updatedReceipt.foodItems,
                tax: updatedReceipt.tax,
                tip: updatedReceipt.tip,
                gratuity: updatedItem,
                subtotal: updatedReceipt.subtotal,
                total: updatedReceipt.total,
                discounts: updatedReceipt.discounts,
                otherCharges: updatedReceipt.otherCharges,
                unknownItems: updatedReceipt.unknownItems,
                totalConfidence: updatedReceipt.totalConfidence,
                validationStatus: updatedReceipt.validationStatus,
                validationIssues: updatedReceipt.validationIssues
            )
        case .subtotal:
            updatedReceipt = ClassifiedReceipt(
                foodItems: updatedReceipt.foodItems,
                tax: updatedReceipt.tax,
                tip: updatedReceipt.tip,
                gratuity: updatedReceipt.gratuity,
                subtotal: updatedItem,
                total: updatedReceipt.total,
                discounts: updatedReceipt.discounts,
                otherCharges: updatedReceipt.otherCharges,
                unknownItems: updatedReceipt.unknownItems,
                totalConfidence: updatedReceipt.totalConfidence,
                validationStatus: updatedReceipt.validationStatus,
                validationIssues: updatedReceipt.validationIssues
            )
        case .total:
            updatedReceipt = ClassifiedReceipt(
                foodItems: updatedReceipt.foodItems,
                tax: updatedReceipt.tax,
                tip: updatedReceipt.tip,
                gratuity: updatedReceipt.gratuity,
                subtotal: updatedReceipt.subtotal,
                total: updatedItem,
                discounts: updatedReceipt.discounts,
                otherCharges: updatedReceipt.otherCharges,
                unknownItems: updatedReceipt.unknownItems,
                totalConfidence: updatedReceipt.totalConfidence,
                validationStatus: updatedReceipt.validationStatus,
                validationIssues: updatedReceipt.validationIssues
            )
        case .discount:
            var discounts = updatedReceipt.discounts
            discounts.append(updatedItem)
            updatedReceipt = ClassifiedReceipt(
                foodItems: updatedReceipt.foodItems,
                tax: updatedReceipt.tax,
                tip: updatedReceipt.tip,
                gratuity: updatedReceipt.gratuity,
                subtotal: updatedReceipt.subtotal,
                total: updatedReceipt.total,
                discounts: discounts.sorted { $0.position < $1.position },
                otherCharges: updatedReceipt.otherCharges,
                unknownItems: updatedReceipt.unknownItems,
                totalConfidence: updatedReceipt.totalConfidence,
                validationStatus: updatedReceipt.validationStatus,
                validationIssues: updatedReceipt.validationIssues
            )
        case .serviceCharge, .deliveryFee:
            var otherCharges = updatedReceipt.otherCharges
            otherCharges.append(updatedItem)
            updatedReceipt = ClassifiedReceipt(
                foodItems: updatedReceipt.foodItems,
                tax: updatedReceipt.tax,
                tip: updatedReceipt.tip,
                gratuity: updatedReceipt.gratuity,
                subtotal: updatedReceipt.subtotal,
                total: updatedReceipt.total,
                discounts: updatedReceipt.discounts,
                otherCharges: otherCharges.sorted { $0.position < $1.position },
                unknownItems: updatedReceipt.unknownItems,
                totalConfidence: updatedReceipt.totalConfidence,
                validationStatus: updatedReceipt.validationStatus,
                validationIssues: updatedReceipt.validationIssues
            )
        case .unknown:
            var unknownItems = updatedReceipt.unknownItems
            unknownItems.append(updatedItem)
            updatedReceipt = ClassifiedReceipt(
                foodItems: updatedReceipt.foodItems,
                tax: updatedReceipt.tax,
                tip: updatedReceipt.tip,
                gratuity: updatedReceipt.gratuity,
                subtotal: updatedReceipt.subtotal,
                total: updatedReceipt.total,
                discounts: updatedReceipt.discounts,
                otherCharges: updatedReceipt.otherCharges,
                unknownItems: unknownItems.sorted { $0.position < $1.position },
                totalConfidence: updatedReceipt.totalConfidence,
                validationStatus: updatedReceipt.validationStatus,
                validationIssues: updatedReceipt.validationIssues
            )
        }

        classifiedReceipt = updatedReceipt
    }
}

// MARK: - Category Picker View

struct CategoryPickerView: View {
    let item: ClassifiedReceiptItem
    let onSave: (ClassifiedReceiptItem) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: ItemCategory

    init(item: ClassifiedReceiptItem, onSave: @escaping (ClassifiedReceiptItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _selectedCategory = State(initialValue: item.category)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    HStack {
                        Text("Name")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(item.name)
                    }

                    HStack {
                        Text("Price")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", item.price))")
                    }

                    HStack {
                        Text("Current Category")
                            .foregroundColor(.secondary)
                        Spacer()
                        Label(item.category.displayName, systemImage: item.category.icon)
                    }

                    HStack {
                        Text("Confidence")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(item.classificationConfidence * 100))%")
                            .foregroundColor(item.confidenceLevel.color)
                    }
                }

                Section(header: Text("Change Category")) {
                    ForEach(ItemCategory.allCases, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                        }) {
                            HStack {
                                Label(category.displayName, systemImage: category.icon)
                                    .foregroundColor(.primary)

                                Spacer()

                                if selectedCategory == category {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Classification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedItem = item.corrected(to: selectedCategory, by: "user")
                        onSave(updatedItem)
                        dismiss()
                    }
                    .disabled(selectedCategory == item.category)
                }
            }
        }
    }
}

// MARK: - Supporting Extensions

extension ValidationStatus {
    var icon: String {
        switch self {
        case .valid: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .invalid: return "xmark.circle.fill"
        case .needsReview: return "eye.fill"
        }
    }

    var color: Color {
        switch self {
        case .valid: return .green
        case .warning: return .orange
        case .invalid: return .red
        case .needsReview: return .blue
        }
    }

    var displayName: String {
        switch self {
        case .valid: return "Valid"
        case .warning: return "Warning"
        case .invalid: return "Invalid"
        case .needsReview: return "Needs Review"
        }
    }
}

extension ConfidenceLevel {
    var icon: String {
        switch self {
        case .high: return "checkmark.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low: return "exclamationmark.circle.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .placeholder: return .gray
        }
    }

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .placeholder: return "Placeholder"
        }
    }
}

extension ClassificationMethod {
    var displayName: String {
        switch self {
        case .geometric: return "Position"
        case .heuristic: return "Pattern"
        case .priceRelationship: return "Math"
        case .llm: return "AI"
        case .manual: return "Manual"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ClassificationReviewView(
            classifiedReceipt: .constant(ClassifiedReceipt(
                foodItems: [
                    ClassifiedReceiptItem(
                        id: "1",
                        name: "Burger",
                        price: 12.99,
                        category: .food,
                        classificationConfidence: 0.95,
                        classificationMethod: .heuristic,
                        originalText: "Burger",
                        position: 0,
                        createdAt: Date(),
                        updatedAt: Date(),
                        correctedBy: nil,
                        correctedAt: nil
                    )
                ],
                tax: ClassifiedReceiptItem(
                    id: "2",
                    name: "Tax",
                    price: 1.30,
                    category: .tax,
                    classificationConfidence: 0.88,
                    classificationMethod: .priceRelationship,
                    originalText: "Tax",
                    position: 1,
                    createdAt: Date(),
                    updatedAt: Date(),
                    correctedBy: nil,
                    correctedAt: nil
                ),
                tip: nil,
                gratuity: nil,
                subtotal: nil,
                total: ClassifiedReceiptItem(
                    id: "3",
                    name: "Total",
                    price: 14.29,
                    category: .total,
                    classificationConfidence: 0.92,
                    classificationMethod: .geometric,
                    originalText: "Total",
                    position: 2,
                    createdAt: Date(),
                    updatedAt: Date(),
                    correctedBy: nil,
                    correctedAt: nil
                ),
                discounts: [],
                otherCharges: [],
                unknownItems: [],
                totalConfidence: 0.92,
                validationStatus: .valid,
                validationIssues: []
            )),
            onComplete: {}
        )
    }
}
