//
//  View+KeyboardToolbar.swift
//  Settled Design System
//
//  Reusable keyboard toolbar with "Done" button
//  Automatically dismisses keyboard when tapped
//

import SwiftUI

extension View {
    /// Adds a "Done" button toolbar above the keyboard
    /// Use for: Numeric keyboards, decimal pads, or any keyboard without a return key
    /// - Parameter focusState: Optional FocusState binding to programmatically dismiss keyboard
    func keyboardDoneButton() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    // Dismiss keyboard by resigning first responder
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.buttonText)
                .foregroundColor(.adaptiveAccentBlue)
            }
        }
    }
}

// MARK: - Usage Examples
/*

 Basic Usage with TextField:
 ```
 TextField("0.00", text: $amount)
     .keyboardType(.decimalPad)
     .keyboardDoneButton()
 ```

 With Multiple TextFields:
 ```
 VStack {
     TextField("Tax", text: $tax)
         .keyboardType(.decimalPad)
         .keyboardDoneButton()

     TextField("Tip", text: $tip)
         .keyboardType(.decimalPad)
         .keyboardDoneButton()
 }
 ```

 With StyledTextField:
 ```
 StyledTextField(
     label: "Amount",
     placeholder: "0.00",
     text: $amount,
     keyboardType: .decimalPad
 )
 .keyboardDoneButton()
 ```

 */
