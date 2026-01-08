//
//  BillEditConfirmation.swift
//  Settled
//
//  Bill edit confirmation view (replaces scan screen for editing)
//  Allows verification and adjustment of bill details before assignment
//

import SwiftUI

struct BillEditConfirmationView: View {
    let bill: Bill
    @ObservedObject var session: BillSplitSession
    let onContinue: () -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var editedTax: String = "0.00"
    @State private var editedTip: String = "0.00"
    @State private var editedTotal: String = ""
    @State private var editedItemCount: String = ""

    private var calculatedSubtotal: Double {
        session.scannedItems.reduce(0) { $0 + $1.price }
    }

    private var totalWithTaxAndTip: Double {
        let tax = Double(editedTax) ?? 0.0
        let tip = Double(editedTip) ?? 0.0
        return calculatedSubtotal + tax + tip
    }

    private var totalsMatch: Bool {
        let enteredTotal = Double(editedTotal) ?? 0.0
        return abs(totalWithTaxAndTip - enteredTotal) <= 0.01
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header and description - close spacing as they belong together
                VStack(spacing: .spacingXS) {
                    Text("Verify Bill Details")
                        .font(.h3Dynamic)
                        .foregroundColor(.adaptiveTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Review and adjust the bill details before proceeding to assign items.")
                        .font(.smallDynamic)
                        .foregroundColor(.adaptiveTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, .paddingScreen)

                // Bill Details Form - Clean layout matching OCR Confirmation
                VStack(spacing: 16) {
                    // Subtotal (calculated, read-only)
                    HStack(spacing: 12) {
                        // Label on left
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subtotal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.adaptiveTextPrimary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Read-only value on right
                        Text("$\(calculatedSubtotal, specifier: "%.2f")")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.adaptiveTextSecondary)
                    }
                    .padding(.horizontal, .paddingScreen)

                    // Number of Items Field
                    HStack(spacing: 12) {
                        // Label on left
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("Number of Items")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.adaptiveTextPrimary)
                                    .lineLimit(1)
                                Text("*")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.adaptiveAccentRed)
                            }
                        }

                        Spacer()

                        // Input field on right - same size as others
                        TextField("\(session.scannedItems.count)", text: $editedItemCount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.adaptiveTextPrimary)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                            .padding(.spacingMD)
                            .background(
                                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                    .fill(Color.adaptiveDepth3)
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                            )
                    }
                    .padding(.horizontal, .paddingScreen)

                    // Tax Amount Field
                    HStack(spacing: 12) {
                        // Label on left
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tax Amount")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.adaptiveTextPrimary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Input field on right
                        HStack(spacing: 4) {
                            Text("$")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.adaptiveTextPrimary)
                            TextField("0.00", text: $editedTax)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.adaptiveTextPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(width: 140)
                        .padding(.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                .fill(Color.adaptiveDepth3)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                        )
                    }
                    .padding(.horizontal, .paddingScreen)

                    // Tip Amount Field
                    HStack(spacing: 12) {
                        // Label on left
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tip Amount")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.adaptiveTextPrimary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Input field on right
                        HStack(spacing: 4) {
                            Text("$")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.adaptiveTextPrimary)
                            TextField("0.00", text: $editedTip)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.adaptiveTextPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(width: 140)
                        .padding(.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                .fill(Color.adaptiveDepth3)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                        )
                    }
                    .padding(.horizontal, .paddingScreen)

                    // Total Amount Field
                    HStack(spacing: 12) {
                        // Label on left
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("Total Amount")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.adaptiveTextPrimary)
                                    .lineLimit(1)
                                Text("*")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.adaptiveAccentRed)
                            }
                        }

                        Spacer()

                        // Input field on right
                        HStack(spacing: 4) {
                            Text("$")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.adaptiveTextPrimary)
                            TextField("\(bill.totalAmount, specifier: "%.2f")", text: $editedTotal)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.adaptiveTextPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(width: 140)
                        .padding(.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                .fill(Color.adaptiveDepth3)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                        )
                    }
                    .padding(.horizontal, .paddingScreen)
                    .padding(.bottom, .spacingMD)  // Add spacing before validation message/button
                }

                // Validation message - only show error
                if !totalsMatch {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.adaptiveAccentOrange)
                        Text("Totals don't match. Please verify the amounts above.")
                            .font(.subheadline)
                            .foregroundColor(.adaptiveAccentOrange)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.adaptiveAccentOrange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                // Continue Button
                if totalsMatch {
                    Button(action: {
                        // Update session with confirmed values
                        session.confirmedTax = Double(editedTax) ?? 0.0
                        session.confirmedTip = Double(editedTip) ?? 0.0
                        session.confirmedTotal = Double(editedTotal) ?? totalWithTaxAndTip
                        session.expectedItemCount = Int(editedItemCount) ?? session.scannedItems.count
                        session.identifiedTotal = session.confirmedTotal

                        onContinue()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Continue to Assign Items")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                } else {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Continue to Assign Items")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(true)
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .background(Color.adaptiveDepth0)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .foregroundColor(.adaptiveAccentBlue)
            }
        }
        .onAppear {
            // Initialize editable fields with current values
            editedTax = String(format: "%.2f", session.confirmedTax)
            editedTip = String(format: "%.2f", session.confirmedTip)
            editedTotal = String(format: "%.2f", session.confirmedTotal)
            editedItemCount = "\(session.expectedItemCount)"
        }
    }
}
