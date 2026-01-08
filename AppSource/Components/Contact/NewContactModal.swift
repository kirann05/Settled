import SwiftUI

/**
 * New Contact Creation Modal
 * 
 * Modal interface for adding new contacts to the user's transaction network.
 * Provides a clean form interface with validation and error handling.
 * 
 * Features:
 * - Pre-filled email from search
 * - Required full name validation
 * - Optional phone number field
 * - Real-time form validation
 * - Async contact creation with loading states
 * - Comprehensive error handling
 * 
 * Architecture: MVVM with async operations for contact management
 */

struct NewContactModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var contactsManager: ContactsManager
    @ObservedObject var authViewModel: AuthViewModel
    
    let prefilledEmail: String
    let onContactSaved: (TransactionContact) -> Void
    
    @State private var fullName: String = ""
    @State private var phoneNumber: String = ""
    @State private var isLoading = false
    @State private var validationError: String?
    @State private var showErrorAlert = false
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Icon and description
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.adaptiveAccentBlue.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.adaptiveAccentBlue)
                            )
                        
                        VStack(spacing: 8) {
                            Text("Add to Network")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Save this contact to easily add them to future bills")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Form
                    VStack(spacing: 24) {
                        // Full Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Full Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("*")
                                    .font(.subheadline)
                                    .foregroundColor(.adaptiveAccentRed)
                            }
                            
                            TextField("Enter full name", text: $fullName)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .focused($isNameFieldFocused)
                                .autocapitalization(.words)
                                .disableAutocorrection(true)
                        }
                        
                        // Email Field (read-only)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                                
                                Text(prefilledEmail)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        }
                        
                        // Phone Number Field (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone Number (Optional)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter phone number", text: $phoneNumber)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .keyboardType(.phonePad)
                        }
                        
                        // Error message
                        if let errorMessage = validationError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.adaptiveAccentRed)
                                    .font(.system(size: 14))
                                
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.adaptiveAccentRed)
                                
                                Spacer()
                            }
                            .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveContact) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Add")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                    .foregroundColor(.adaptiveAccentBlue)
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
        .onAppear {
            isNameFieldFocused = true
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(validationError ?? "An error occurred")
        }
    }
    
    /// Validates that all required fields are filled
    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /**
     * Saves the new contact with comprehensive validation and error handling.
     * 
     * Process:
     * 1. Validates contact data asynchronously
     * 2. Saves to Firestore if validation passes
     * 3. Updates UI with success/error states
     * 4. Dismisses modal on success
     */
    private func saveContact() {
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneToSave = trimmedPhone.isEmpty ? nil : trimmedPhone
        
        isLoading = true
        validationError = nil
        
        Task {
            do {
                // Validate the transaction contact (now async)
                let validation = await contactsManager.validateNewTransactionContact(
                    displayName: fullName,
                    email: prefilledEmail,
                    phoneNumber: phoneToSave,
                    authViewModel: authViewModel
                )
                
                guard validation.isValid, let contact = validation.contact else {
                    await MainActor.run {
                        isLoading = false
                        validationError = validation.error
                        showErrorAlert = true
                    }
                    return
                }
                
                try await contactsManager.saveTransactionContact(contact)
                
                await MainActor.run {
                    isLoading = false
                    onContactSaved(contact)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    validationError = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
    
    /// Dismisses the keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}