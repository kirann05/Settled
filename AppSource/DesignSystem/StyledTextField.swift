//
//  StyledTextField.swift
//  Settled Design System
//
//  Reusable text field with consistent styling and focus states
//  Includes label, placeholder, and design system integration
//

import SwiftUI

// MARK: - Styled Text Field
/// Text field with label, focus states, and design system styling
/// Use for: Form inputs, search fields, user data entry
struct StyledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false
    var accessibilityHintText: String?

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingSM) {
            // Label
            Text(label)
                .font(.inputLabel)
                .foregroundColor(.adaptiveTextPrimary)
                .accessibilityHidden(true)

            // Text Input
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textInputAutocapitalization(.none)
                        .keyboardType(keyboardType)
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(autocapitalization)
                        .keyboardType(keyboardType)
                }
            }
            .font(.cerealBody)
            .foregroundColor(.adaptiveTextPrimary)
            .padding(.spacingMD)
            .background(Color.adaptiveDepth1)
            .cornerRadius(.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                    .stroke(
                        isFocused ? Color.accentColor : Color.adaptiveTextPrimary.opacity(0.2),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .focused($isFocused)
            .animation(reduceMotion ? .none : .smoothEaseOut, value: isFocused)
            .accessibilityLabel(label)
            .accessibilityValue(text.isEmpty ? "Empty" : text)
            .accessibilityHint(accessibilityHintText ?? "Enter \(label.lowercased())")
        }
    }
}

// MARK: - Styled Text Field with Error
/// Text field with error state and message support
/// Use for: Form validation, error display, required fields
struct StyledTextFieldWithError: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var errorMessage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var accessibilityHintText: String?

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private var hasError: Bool {
        errorMessage != nil && !errorMessage!.isEmpty
    }

    private var borderColor: Color {
        if hasError {
            return .red
        } else if isFocused {
            return .accentColor
        } else {
            return .adaptiveTextPrimary.opacity(0.2)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingSM) {
            // Label
            Text(label)
                .font(.inputLabel)
                .foregroundColor(.adaptiveTextPrimary)
                .accessibilityHidden(true)

            // Text Input
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(autocapitalization)
                .keyboardType(keyboardType)
                .font(.cerealBody)
                .foregroundColor(.adaptiveTextPrimary)
                .padding(.spacingMD)
                .background(Color.adaptiveDepth1)
                .cornerRadius(.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                        .stroke(borderColor, lineWidth: hasError || isFocused ? 2 : 1)
                )
                .focused($isFocused)
                .animation(reduceMotion ? .none : .smoothEaseOut, value: isFocused)
                .accessibilityLabel(label)
                .accessibilityValue(text.isEmpty ? "Empty" : text)
                .accessibilityHint(hasError ? errorMessage! : (accessibilityHintText ?? "Enter \(label.lowercased())"))

            // Error Message
            if hasError {
                HStack(spacing: .spacingXS) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.cerealCaption)
                    Text(errorMessage!)
                        .font(.cerealCaption)
                }
                .foregroundColor(.adaptiveAccentRed)
                .transition(.opacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Error: \(errorMessage!)")
            }
        }
    }
}

// MARK: - Search Field
/// Search-optimized text field with search icon
/// Use for: Search bars, filter inputs, lookup fields
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        HStack(spacing: .spacingMD) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.adaptiveTextTertiary)
                .font(.body)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.cerealBody)
                .foregroundColor(.adaptiveTextPrimary)
                .focused($isFocused)
                .accessibilityLabel("Search field")
                .accessibilityValue(text.isEmpty ? "Empty" : text)
                .accessibilityHint("Enter text to search")

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.adaptiveTextTertiary)
                        .font(.body)
                }
                .accessibilityLabel("Clear search")
                .accessibilityHint("Clears the current search text")
            }
        }
        .padding(.spacingMD)
        .background(Color.adaptiveDepth1)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(
                    isFocused ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(reduceMotion ? .none : .smoothEaseOut, value: isFocused)
        .animation(reduceMotion ? .none : .smoothEaseOut, value: text.isEmpty)
    }
}

// MARK: - Preview Provider
struct StyledTextField_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var username = ""
        @State private var email = "test@example.com"
        @State private var password = ""
        @State private var searchText = ""
        @State private var invalidEmail = "invalid"
        @State private var amount = ""

        var body: some View {
            ScrollView {
                VStack(spacing: .spacingLG) {
                    // Basic Text Field
                    StyledTextField(
                        label: "Username",
                        placeholder: "Enter your username",
                        text: $username,
                        accessibilityHintText: "Enter your username for login"
                    )

                    // Email Text Field
                    StyledTextField(
                        label: "Email Address",
                        placeholder: "you@example.com",
                        text: $email,
                        keyboardType: .emailAddress,
                        autocapitalization: .never,
                        accessibilityHintText: "Enter your email address"
                    )

                    // Secure Text Field
                    StyledTextField(
                        label: "Password",
                        placeholder: "Enter password",
                        text: $password,
                        isSecure: true,
                        accessibilityHintText: "Enter your password securely"
                    )

                    // Text Field with Error
                    StyledTextFieldWithError(
                        label: "Email (with error)",
                        placeholder: "you@example.com",
                        text: $invalidEmail,
                        errorMessage: "Please enter a valid email address",
                        keyboardType: .emailAddress,
                        autocapitalization: .never,
                        accessibilityHintText: "Enter a valid email address"
                    )

                    // Numeric Text Field
                    StyledTextField(
                        label: "Amount",
                        placeholder: "0.00",
                        text: $amount,
                        keyboardType: .decimalPad,
                        accessibilityHintText: "Enter amount in dollars"
                    )

                    // Search Field
                    VStack(alignment: .leading, spacing: .spacingSM) {
                        Text("Search")
                            .font(.inputLabel)
                            .foregroundColor(.adaptiveTextPrimary)

                        SearchField(
                            placeholder: "Search for anything...",
                            text: $searchText
                        )
                    }
                }
                .padding(.paddingScreen)
            }
            .background(Color.adaptiveDepth0)
        }
    }

    static var previews: some View {
        Group {
            PreviewContainer()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")

            PreviewContainer()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}

// MARK: - Accessibility
extension StyledTextField {
    /// Add custom accessibility hint to text field
    func accessibilityCustomHint(_ hint: String) -> some View {
        var view = self
        view.accessibilityHintText = hint
        return view
    }
}

// MARK: - Usage Examples
/*

 Basic Text Field:
 ```
 @State private var username = ""

 StyledTextField(
     label: "Username",
     placeholder: "Enter your username",
     text: $username,
     accessibilityHintText: "Enter your username for login"
 )
 ```

 Email Input:
 ```
 @State private var email = ""

 StyledTextField(
     label: "Email",
     placeholder: "you@example.com",
     text: $email,
     keyboardType: .emailAddress,
     autocapitalization: .never,
     accessibilityHintText: "Enter your email address"
 )
 ```

 Secure Password:
 ```
 @State private var password = ""

 StyledTextField(
     label: "Password",
     placeholder: "Enter password",
     text: $password,
     isSecure: true,
     accessibilityHintText: "Enter your password securely"
 )
 ```

 Text Field with Validation:
 ```
 @State private var email = ""
 @State private var emailError: String? = nil

 StyledTextFieldWithError(
     label: "Email",
     placeholder: "you@example.com",
     text: $email,
     errorMessage: emailError,
     keyboardType: .emailAddress,
     accessibilityHintText: "Enter a valid email address"
 )
 ```

 Search Field:
 ```
 @State private var searchText = ""

 SearchField(
     placeholder: "Search bills...",
     text: $searchText
 )
 ```

 */
