import SwiftUI

/**
 * Item Assignment Components
 * 
 * Collection of UI components for managing bill item assignments and participant interactions.
 * 
 * Components included:
 * - ParticipantChip: Deletable participant representation with confirmation
 * - UIItemAssignCard: Editable item card with participant assignment
 * - RegexItemCard: Read-only display for regex-detected items
 * - EditableRegexItemCard: Editable version of regex items
 * - LLMItemCard: Read-only display for AI-detected items
 * - ParticipantAssignmentRow: Horizontal scroll participant selection
 * 
 * Architecture: Reusable SwiftUI components with confidence indicators
 * Features: Real-time editing, confidence scoring, assignment feedback
 */

// MARK: - Participant Chip Component

/**
 * Participant Chip - Deletable Participant Display
 * 
 * Compact participant representation with optional delete functionality.
 * 
 * Features:
 * - Color-coded participant avatar
 * - Name display with text truncation
 * - Conditional delete button with confirmation dialog
 * - Consistent styling with shadow and corner radius
 */
struct ParticipantChip: View {
    let participant: UIParticipant
    let canDelete: Bool
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(participant.color)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                )
            
            Text(participant.name)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Spacer()
            
            if canDelete {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.8))
                        .font(.title3)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .alert("Remove Participant", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to remove \(participant.name) from this bill split? Any items assigned to them will become unassigned.")
        }
    }
}

// MARK: - Item Assignment Card

/**
 * UIItemAssignCard - Editable Item with Participant Assignment
 * 
 * Interactive item card for editing item details and assigning to participants.
 * 
 * Features:
 * - Editable item name and price fields
 * - Confidence indicators with icons and colors
 * - Assignment status display
 * - Participant selection grid when unassigned
 * - Focus state management for form fields
 */
struct UIItemAssignCard: View {
    @Binding var item: UIItem
    let participants: [UIParticipant]

    @State private var showInvalidPriceAlert = false
    @State private var tempPrice: String = ""

    var assignedParticipant: UIParticipant? {
        participants.first { $0.id == item.assignedTo }
    }
    
    // Confidence display properties
    var confidenceColor: Color {
        switch item.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .placeholder: return .gray
        }
    }
    
    var confidenceText: String {
        switch item.confidence {
        case .high: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .medium: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .low: return "Low confidence"
        case .placeholder: return "Please verify"
        }
    }
    
    var confidenceIcon: String {
        switch item.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }
    
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isPriceFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Editable Item Name
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Item Name", text: $item.name)
                        .fontWeight(.medium)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            isNameFieldFocused = false
                        }
                    
                    // Confidence indicator
                    HStack(spacing: 4) {
                        Image(systemName: confidenceIcon)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                        
                        Text(confidenceText)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                    }
                }
                
                Spacer()
                
                // Editable Price with validation
                HStack(spacing: 4) {
                    Text("$")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Price", text: $tempPrice)
                        .keyboardType(.decimalPad)
                        .fixedSize()
                        .focused($isPriceFieldFocused)
                        .onAppear {
                            tempPrice = String(format: "%.2f", item.price)
                        }
                        .onChange(of: tempPrice) { newValue in
                            validateAndUpdatePrice(newValue)
                        }
                        .onSubmit {
                            isPriceFieldFocused = false
                        }
                }
                .alert("Invalid Price", isPresented: $showInvalidPriceAlert) {
                    Button("OK", role: .cancel) {
                        tempPrice = String(format: "%.2f", item.price)
                    }
                } message: {
                    Text("Price must be greater than $0.00. Discounts and zero-amount items are not allowed.")
                }
                
                if let assigned = assignedParticipant {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(assigned.color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                                    .font(.caption2)
                            )
                        Text(assigned.name)
                            .font(.caption)
                    }
                } else {
                    Text("Unassigned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            if assignedParticipant == nil {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(participants) { participant in
                        Button(participant.name) {
                            item.assignedTo = participant.id
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(participant.color)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(assignedParticipant != nil ? Color.adaptiveDepth1.opacity(0.5) : Color.adaptiveDepth0)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(assignedParticipant != nil ? Color.adaptiveTextTertiary.opacity(0.3) : Color.adaptiveTextTertiary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Price Validation (EDGE-001)

    /// Validates price input and updates item.price only if valid (>$0.00)
    private func validateAndUpdatePrice(_ newValue: String) {
        // Allow empty or partial input during typing
        guard !newValue.isEmpty else { return }

        // Try to parse as Double
        if let price = Double(newValue) {
            if price > 0.00 {
                // Valid price - update item
                item.price = price
            } else {
                // Invalid price (zero or negative) - show alert and revert
                showInvalidPriceAlert = true
            }
        }
        // If parse fails, ignore - user is still typing
    }
}

// MARK: - Regex Item Card (Read-only)

/**
 * RegexItemCard - Read-only Display for Regex-Detected Items
 * 
 * Display component for items detected using regex pattern matching.
 * 
 * Features:
 * - Read-only item name and price display
 * - Confidence indicators with appropriate colors
 * - "REGEX" badge for detection method identification
 * - Consistent styling with other item cards
 */
struct RegexItemCard: View {
    let item: ReceiptItem
    let participants: [UIParticipant]
    
    // Confidence display properties
    var confidenceColor: Color {
        switch item.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .placeholder: return .gray
        }
    }
    
    var confidenceText: String {
        switch item.confidence {
        case .high: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .medium: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .low: return "Low confidence"
        case .placeholder: return "Please verify"
        }
    }
    
    var confidenceIcon: String {
        switch item.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Item Name (Read-only)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Confidence indicator
                    HStack(spacing: 4) {
                        Image(systemName: confidenceIcon)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                        
                        Text(confidenceText)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                    }
                }
                
                Spacer()
                
                // Price (Read-only)
                Text("$\(String(format: "%.2f", item.price))")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Regex badge
                Text("REGEX")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.adaptiveAccentOrange.opacity(0.2))
                    .foregroundColor(.adaptiveAccentOrange)
                    .cornerRadius(4)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Editable Regex Item Card

/**
 * EditableRegexItemCard - Editable Version of Regex Items
 * 
 * Editable item card specifically for regex-detected items.
 * 
 * Features:
 * - Editable item name and price fields
 * - Confidence indicators for detection quality
 * - "REGEX" badge for method identification
 * - Focus state management for form inputs
 */
struct EditableRegexItemCard: View {
    @Binding var item: UIItem
    let participants: [UIParticipant]

    @State private var showInvalidPriceAlert = false
    @State private var tempPrice: String = ""

    // Confidence display properties
    var confidenceColor: Color {
        switch item.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .placeholder: return .gray
        }
    }

    var confidenceText: String {
        switch item.confidence {
        case .high:
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .medium:
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .low: return "Low confidence"
        case .placeholder: return "Please verify"
        }
    }

    var confidenceIcon: String {
        switch item.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }

    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isPriceFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Editable Item Name
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Item Name", text: $item.name)
                        .fontWeight(.medium)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            isNameFieldFocused = false
                        }

                    // Confidence indicator
                    HStack(spacing: 4) {
                        Image(systemName: confidenceIcon)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)

                        Text(confidenceText)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                    }
                }

                Spacer()

                // Editable Price with validation
                HStack(spacing: 4) {
                    Text("$")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Price", text: $tempPrice)
                        .keyboardType(.decimalPad)
                        .fixedSize()
                        .focused($isPriceFieldFocused)
                        .onAppear {
                            tempPrice = String(format: "%.2f", item.price)
                        }
                        .onChange(of: tempPrice) { newValue in
                            validateAndUpdatePrice(newValue)
                        }
                        .onSubmit {
                            isPriceFieldFocused = false
                        }
                }
                .alert("Invalid Price", isPresented: $showInvalidPriceAlert) {
                    Button("OK", role: .cancel) {
                        tempPrice = String(format: "%.2f", item.price)
                    }
                } message: {
                    Text("Price must be greater than $0.00. Discounts and zero-amount items are not allowed.")
                }

                // Regex badge
                Text("REGEX")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.adaptiveAccentOrange.opacity(0.2))
                    .foregroundColor(.adaptiveAccentOrange)
                    .cornerRadius(4)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Price Validation (EDGE-001)

    /// Validates price input and updates item.price only if valid (>$0.00)
    private func validateAndUpdatePrice(_ newValue: String) {
        // Allow empty or partial input during typing
        guard !newValue.isEmpty else { return }

        // Try to parse as Double
        if let price = Double(newValue) {
            if price > 0.00 {
                // Valid price - update item
                item.price = price
            } else {
                // Invalid price (zero or negative) - show alert and revert
                showInvalidPriceAlert = true
            }
        }
        // If parse fails, ignore - user is still typing
    }
}

// MARK: - Apple Intelligence Item Card

/**
 * LLMItemCard - Read-only Display for AI-Detected Items
 * 
 * Display component for items detected using Apple Intelligence/LLM processing.
 * 
 * Features:
 * - Read-only item name and price display
 * - Confidence indicators for AI detection quality
 * - "APPLE AI" badge for method identification
 * - Consistent styling with detection method branding
 */
struct LLMItemCard: View {
    let item: ReceiptItem
    let participants: [UIParticipant]
    
    // Confidence display properties
    var confidenceColor: Color {
        switch item.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        case .placeholder: return .gray
        }
    }
    
    var confidenceText: String {
        switch item.confidence {
        case .high: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .medium: 
            if let originalPrice = item.originalDetectedPrice {
                return "Detected: $\(String(format: "%.2f", originalPrice))"
            } else {
                return "Detected: $\(String(format: "%.2f", item.price))"
            }
        case .low: return "Low confidence"
        case .placeholder: return "Please verify"
        }
    }
    
    var confidenceIcon: String {
        switch item.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .placeholder: return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Item Name (Read-only)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Confidence indicator
                    HStack(spacing: 4) {
                        Image(systemName: confidenceIcon)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                        
                        Text(confidenceText)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                    }
                }
                
                Spacer()
                
                // Price (Read-only)
                Text("$\(String(format: "%.2f", item.price))")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Apple Intelligence badge
                Text("APPLE AI")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.adaptiveAccentBlue.opacity(0.2))
                    .foregroundColor(.adaptiveAccentBlue)
                    .cornerRadius(4)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Participant Assignment Row

/**
 * ParticipantAssignmentRow - Horizontal Participant Selection Interface
 * 
 * Scrollable horizontal interface for selecting participants for item assignment.
 * 
 * Features:
 * - "Everyone" button for bulk selection
 * - Individual participant buttons with selection states
 * - Haptic feedback for interactions
 * - Industry-standard spacing and styling
 * - Visual feedback for selection states
 */
struct ParticipantAssignmentRow: View {
    let item: UIItem
    let participants: [UIParticipant]
    let onParticipantToggle: (String) -> Void
    let onParticipantRemove: (String) -> Void
    let everyoneSelected: Bool
    let onEveryoneToggle: () -> Void

    @State private var showingFeedback = false
    @State private var feedbackParticipant: String? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) { // Increased spacing from 8 to 12 for better industry standards
                // Everyone button styled like other participant buttons
                Button(action: {
                    onEveryoneToggle()
                    triggerFeedback(for: "everyone") // Use "everyone" for everyone button
                }) {
                    HStack(spacing: 6) {
                        Text("Everyone")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        if everyoneSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, everyoneSelected ? 10 : 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(everyoneSelected ? Color.indigo : Color(.systemGray5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.indigo, lineWidth: everyoneSelected ? 0 : 1)
                            )
                    )
                    .foregroundColor(everyoneSelected ? .white : .indigo)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Individual participant buttons
                ForEach(participants) { participant in
                    let isSelected = item.assignedToParticipants.contains(participant.id)
                    
                    Button(action: {
                        if isSelected {
                            onParticipantRemove(participant.id)
                        } else {
                            onParticipantToggle(participant.id)
                        }
                        triggerFeedback(for: participant.id)
                    }) {
                        HStack(spacing: 6) {
                            Text(participant.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, isSelected ? 10 : 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isSelected ? participant.color : Color(.systemGray5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(participant.color, lineWidth: isSelected ? 0 : 1)
                                )
                        )
                        .foregroundColor(isSelected ? .white : participant.color)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func triggerFeedback(for participantId: String) {
        feedbackParticipant = participantId
        showingFeedback = true

        // Light haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Reset feedback state after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showingFeedback = false
            feedbackParticipant = nil
        }
    }
}

// MARK: - Item Row with Participants

/**
 * ItemRowWithParticipants - Complete Item Assignment Interface
 * 
 * Comprehensive item row combining item details with participant assignment controls.
 * 
 * Features:
 * - Item name and price display with cost-per-participant calculation
 * - Visual assignment status indicator with animations
 * - Integrated participant assignment interface
 * - Success animations for user feedback
 * - "Everyone" button for bulk assignment/unassignment
 * - Real-time state synchronization
 * 
 * Architecture: Stateful component with animation and feedback systems
 */
struct ItemRowWithParticipants: View {
    @Binding var item: UIItem
    let participants: [UIParticipant]
    let onItemUpdate: (UIItem) -> Void
    
    @State private var showingSuccessAnimation = false
    @State private var isEveryoneSelected = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Item details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        if item.assignedToParticipants.isEmpty {
                            Text("*")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                        }
                        Text(item.name)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 8) {
                        Text("$\(item.price, specifier: "%.2f")")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if !item.assignedToParticipants.isEmpty {
                            Text("($\(item.costPerParticipant, specifier: "%.2f") each)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Assignment status indicator
                Circle()
                    .fill(item.assignedToParticipants.isEmpty ? Color.adaptiveAccentOrange : Color.adaptiveAccentGreen)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(showingSuccessAnimation ? Color.adaptiveAccentGreen.opacity(0.3) : Color.clear)
                            .scaleEffect(showingSuccessAnimation ? 2.0 : 1.0)
                            .animation(.easeOut(duration: 0.4), value: showingSuccessAnimation)
                    )
            }
            
            // Horizontal line separator
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            // Participant assignment row
            if !participants.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // Combined assignment row with Everyone button and participants
                    ParticipantAssignmentRow(
                        item: item,
                        participants: participants,
                        onParticipantToggle: { participantId in
                            toggleParticipant(participantId)
                        },
                        onParticipantRemove: { participantId in
                            removeParticipant(participantId)
                        },
                        everyoneSelected: isEveryoneSelected,
                        onEveryoneToggle: {
                            toggleEveryoneButton()
                        }
                    )
                }
            }
        }
        .padding(.paddingScreen)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            updateEveryoneButtonState()
        }
        .onChange(of: item.assignedToParticipants) {
            updateEveryoneButtonState()
        }
    }
    
    private func toggleParticipant(_ participantId: String) {
        if item.assignedToParticipants.contains(participantId) {
            removeParticipant(participantId)
        } else {
            addParticipant(participantId)
        }
    }

    private func addParticipant(_ participantId: String) {
        item.assignedToParticipants.insert(participantId)
        onItemUpdate(item)
        triggerSuccessAnimation()
    }

    private func removeParticipant(_ participantId: String) {
        item.assignedToParticipants.remove(participantId)
        onItemUpdate(item)
        triggerSuccessAnimation()
    }
    
    private func triggerSuccessAnimation() {
        showingSuccessAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showingSuccessAnimation = false
        }
    }
    
    private func toggleEveryoneButton() {
        if isEveryoneSelected {
            // Deselect everyone - clear all assignments
            item.assignedToParticipants.removeAll()
            isEveryoneSelected = false
        } else {
            // Select everyone - assign to all participants
            item.assignedToParticipants = Set(participants.map { $0.id })
            isEveryoneSelected = true
        }
        onItemUpdate(item)
        triggerSuccessAnimation()
    }
    
    private func updateEveryoneButtonState() {
        let allParticipantIds = Set(participants.map { $0.id })
        isEveryoneSelected = !item.assignedToParticipants.isEmpty && 
                                 item.assignedToParticipants == allParticipantIds
    }
}


// MARK: - Manual Entry Item Row with Editable Name and Price
/**
 * Manual Entry Item Row Component
 * 
 * Enhanced item row for manual bill entry that allows editing both item name and price
 * while maintaining participant assignment functionality.
 * 
 * Features:
 * - Editable item name and price fields
 * - Same participant assignment UI as scan-based items
 * - Delete button to remove items
 * - Real-time validation and updates
 * 
 * Usage: Manual entry mode in AssignScreen
 */
struct ManualItemRowWithParticipants: View {
    @Binding var item: UIItem
    let participants: [UIParticipant]
    let onItemUpdate: (UIItem) -> Void
    let onDelete: () -> Void
    
    @State private var showingSuccessAnimation = false
    @State private var isEveryoneSelected = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name, price
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Editable item name
            HStack(alignment: .center, spacing: 12) {
                Text("Item name")
                    .font(.bodyDynamic)
                    .foregroundColor(.adaptiveTextPrimary)
                    .frame(width: 90, alignment: .leading)
                
                TextField("Enter item name", text: $item.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .name)
                    .onChange(of: item.name) { _ in
                        onItemUpdate(item)
                    }
            }
            
            // Editable item price with delete button
            HStack(alignment: .center, spacing: 12) {
                Text("Item value")
                    .font(.bodyDynamic)
                    .foregroundColor(.adaptiveTextPrimary)
                    .frame(width: 90, alignment: .leading)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("$")
                            .font(.bodyDynamic)
                            .foregroundColor(.adaptiveTextPrimary)
                        
                        TextField("0.00", value: $item.price, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .price)
                            .onChange(of: item.price) { _ in
                                onItemUpdate(item)
                            }
                    }
                    
                    Spacer()
                    
                    // Assignment status indicator
                    Circle()
                        .fill(item.assignedToParticipants.isEmpty ? Color.adaptiveAccentOrange : Color.adaptiveAccentGreen)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .fill(showingSuccessAnimation ? Color.adaptiveAccentGreen.opacity(0.3) : Color.clear)
                                .scaleEffect(showingSuccessAnimation ? 2.0 : 1.0)
                                .animation(.easeOut(duration: 0.4), value: showingSuccessAnimation)
                        )
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 18))
                    }
                }
            }
            
            // Horizontal line separator
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            // Participant assignment row
            if !participants.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // Combined assignment row with Everyone button and participants
                    ParticipantAssignmentRow(
                        item: item,
                        participants: participants,
                        onParticipantToggle: { participantId in
                            toggleParticipant(participantId)
                        },
                        onParticipantRemove: { participantId in
                            removeParticipant(participantId)
                        },
                        everyoneSelected: isEveryoneSelected,
                        onEveryoneToggle: {
                            toggleEveryoneButton()
                        }
                    )
                }
            }
        }
        .padding(.paddingScreen)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            updateEveryoneButtonState()
        }
        .onChange(of: item.assignedToParticipants) {
            updateEveryoneButtonState()
        }
    }
    
    private func toggleParticipant(_ participantId: String) {
        if item.assignedToParticipants.contains(participantId) {
            removeParticipant(participantId)
        } else {
            addParticipant(participantId)
        }
    }

    private func addParticipant(_ participantId: String) {
        item.assignedToParticipants.insert(participantId)
        onItemUpdate(item)
        triggerSuccessAnimation()
    }

    private func removeParticipant(_ participantId: String) {
        item.assignedToParticipants.remove(participantId)
        onItemUpdate(item)
    }

    private func toggleEveryoneButton() {
        if isEveryoneSelected {
            // Remove everyone
            item.assignedToParticipants.removeAll()
        } else {
            // Add everyone
            item.assignedToParticipants = Set(participants.map { $0.id })
            triggerSuccessAnimation()
        }
        onItemUpdate(item)
    }

    private func updateEveryoneButtonState() {
        isEveryoneSelected = !item.assignedToParticipants.isEmpty &&
                            item.assignedToParticipants.count == participants.count
    }

    private func triggerSuccessAnimation() {
        showingSuccessAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showingSuccessAnimation = false
        }
    }
}

// MARK: - Participant Button

/**
 * ParticipantButton - Interactive Participant Selection Button
 * 
 * Advanced button component for participant selection with press animations.
 * 
 * Features:
 * - Color-coded participant representation
 * - Assignment state with visual feedback
 * - Remove button when assigned
 * - Press animation effects
 * - Disabled state handling
 * - Improved spacing and corner radius for modern design
 */
struct ParticipantButton: View {
    let participant: UIParticipant
    let isAssigned: Bool
    let isDisabled: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) { // Increased spacing from 4 to 6
                Text(participant.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if isAssigned && !isDisabled {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, isAssigned ? 10 : 14) // Increased horizontal padding
            .padding(.vertical, 8) // Increased vertical padding from 6 to 8
            .background(
                RoundedRectangle(cornerRadius: 18) // Increased corner radius from 16 to 18
                    .fill(isAssigned ? participant.color.opacity(isDisabled ? 0.6 : 1.0) : Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(participant.color.opacity(isDisabled ? 0.6 : 1.0), lineWidth: isAssigned ? 0 : 1)
                    )
            )
            .foregroundColor(isAssigned ? .white : participant.color.opacity(isDisabled ? 0.6 : 1.0))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if !isDisabled {
                isPressed = pressing
            }
        }, perform: {})
    }
}