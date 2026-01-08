//
//  CustomModal.swift
//  Settled Design System
//
//  Reusable modal components with overlay and animations
//  Includes standard modal, bottom sheet, and confirmation dialogs
//

import SwiftUI

// MARK: - Custom Modal
/// Standard modal with overlay and smooth animations
/// Use for: Dialogs, forms, content overlays
struct CustomModal<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content

    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        ZStack {
            if isPresented {
                // Overlay Background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.modalPresent) {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)

                // Modal Content
                VStack(spacing: 0) {
                    // Close Button
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.modalPresent) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.adaptiveTextSecondary)
                        }
                    }
                    .padding(.spacingMD)

                    // Content
                    content
                        .padding(.horizontal, .paddingCard)
                        .padding(.bottom, .paddingCard)
                }
                .background(Color.adaptiveDepth3)
                .cornerRadius(.cornerRadiusLarge)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.paddingScreen)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.modalPresent, value: isPresented)
    }
}

// MARK: - Bottom Sheet
/// Bottom sheet modal that slides up from bottom
/// Use for: Action sheets, quick options, contextual menus
struct BottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    var detents: Set<PresentationDetent> = [.medium, .large]

    init(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.detents = detents
        self.content = content()
    }

    var body: some View {
        ZStack {
            if isPresented {
                Color.clear
                    .sheet(isPresented: $isPresented) {
                        VStack(spacing: 0) {
                            // Drag Handle
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.adaptiveTextTertiary.opacity(0.5))
                                .frame(width: 40, height: 5)
                                .padding(.vertical, .spacingMD)

                            // Content
                            content
                                .padding(.horizontal, .paddingScreen)
                                .padding(.bottom, .paddingScreen)
                        }
                        .presentationDetents(detents)
                        .presentationDragIndicator(.hidden)
                    }
            }
        }
    }
}

// MARK: - Confirmation Dialog
/// Confirmation dialog with customizable actions
/// Use for: Confirmations, warnings, destructive actions
struct ConfirmationDialog: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmTitle: String
    let confirmAction: () -> Void
    var isDestructive: Bool = false
    var cancelTitle: String = "Cancel"

    var body: some View {
        ZStack {
            if isPresented {
                // Overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.modalPresent) {
                            isPresented = false
                        }
                    }

                // Dialog Content
                VStack(spacing: .spacingLG) {
                    VStack(spacing: .spacingMD) {
                        Text(title)
                            .font(.h3Dynamic)
                            .foregroundColor(.adaptiveTextPrimary)

                        Text(message)
                            .font(.bodyDynamic)
                            .foregroundColor(.adaptiveTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: .spacingMD) {
                        if isDestructive {
                            Button(confirmTitle) {
                                confirmAction()
                                withAnimation(.modalPresent) {
                                    isPresented = false
                                }
                            }
                            .buttonStyle(DestructiveButtonStyle())
                            .frame(maxWidth: .infinity)
                        } else {
                            Button(confirmTitle) {
                                confirmAction()
                                withAnimation(.modalPresent) {
                                    isPresented = false
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: .infinity)
                        }

                        Button(cancelTitle) {
                            withAnimation(.modalPresent) {
                                isPresented = false
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.paddingCard)
                .background(Color.adaptiveDepth3)
                .cornerRadius(.cornerRadiusLarge)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.paddingScreen)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.modalPresent, value: isPresented)
    }
}

// MARK: - Loading Modal
/// Full-screen loading indicator with overlay
/// Use for: Loading states, processing, async operations
struct LoadingModal: View {
    @Binding var isPresented: Bool
    var message: String = "Loading..."

    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                VStack(spacing: .spacingLG) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.accentColor)

                    Text(message)
                        .font(.bodyDynamic)
                        .foregroundColor(.adaptiveTextPrimary)
                }
                .padding(.paddingCard)
                .background(Color.adaptiveDepth3)
                .cornerRadius(.cornerRadiusMedium)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
        }
        .animation(.smoothEaseOut, value: isPresented)
    }
}

// MARK: - Preview Provider
struct CustomModal_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var showModal = false
        @State private var showBottomSheet = false
        @State private var showConfirmation = false
        @State private var showLoading = false

        var body: some View {
            ZStack {
                ScreenContainer {
                    VStack(spacing: .spacingLG) {
                        Text("Modal Components")
                            .heading1()

                        // Modal Trigger
                        Button("Show Modal") {
                            showModal = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)

                        // Bottom Sheet Trigger
                        Button("Show Bottom Sheet") {
                            showBottomSheet = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)

                        // Confirmation Trigger
                        Button("Show Confirmation") {
                            showConfirmation = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)

                        // Loading Trigger
                        Button("Show Loading") {
                            showLoading = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showLoading = false
                            }
                        }
                        .buttonStyle(TertiaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    }
                }

                // Standard Modal
                CustomModal(isPresented: $showModal) {
                    VStack(spacing: .spacingLG) {
                        Text("Modal Title")
                            .heading2()

                        Text("This is a custom modal with overlay and smooth animations. Tap outside or the close button to dismiss.")
                            .bodyStyle(.secondary)

                        Button("Confirm") {
                            showModal = false
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    }
                }

                // Bottom Sheet
                BottomSheet(isPresented: $showBottomSheet) {
                    VStack(spacing: .spacingLG) {
                        Text("Bottom Sheet")
                            .heading3()

                        VStack(spacing: .spacingMD) {
                            Button("Option 1") {}
                                .buttonStyle(SecondaryButtonStyle())
                                .frame(maxWidth: .infinity)

                            Button("Option 2") {}
                                .buttonStyle(SecondaryButtonStyle())
                                .frame(maxWidth: .infinity)

                            Button("Option 3") {}
                                .buttonStyle(SecondaryButtonStyle())
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                // Confirmation Dialog
                ConfirmationDialog(
                    isPresented: $showConfirmation,
                    title: "Delete Bill?",
                    message: "Are you sure you want to delete this bill? This action cannot be undone.",
                    confirmTitle: "Delete",
                    confirmAction: {
                        print("Bill deleted")
                    },
                    isDestructive: true
                )

                // Loading Modal
                LoadingModal(
                    isPresented: $showLoading,
                    message: "Processing..."
                )
            }
        }
    }

    static var previews: some View {
        PreviewContainer()
    }
}

// MARK: - View Extensions
extension View {
    /// Present a custom modal
    func customModal<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.overlay(
            CustomModal(isPresented: isPresented, content: content)
        )
    }

    /// Present a bottom sheet
    func bottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.overlay(
            BottomSheet(isPresented: isPresented, content: content)
        )
    }

    /// Present a loading overlay
    func loadingOverlay(isPresented: Binding<Bool>, message: String = "Loading...") -> some View {
        self.overlay(
            LoadingModal(isPresented: isPresented, message: message)
        )
    }
}

// MARK: - Usage Examples
/*

 Standard Modal:
 ```
 @State private var showModal = false

 Button("Show Modal") {
     showModal = true
 }

 CustomModal(isPresented: $showModal) {
     VStack(spacing: .spacingLG) {
         Text("Modal Content")
             .heading2()

         Button("Done") {
             showModal = false
         }
         .buttonStyle(PrimaryButtonStyle())
     }
 }
 ```

 Bottom Sheet:
 ```
 @State private var showSheet = false

 Button("Show Options") {
     showSheet = true
 }

 BottomSheet(isPresented: $showSheet) {
     VStack(spacing: .spacingMD) {
         Button("Edit") { }
             .buttonStyle(SecondaryButtonStyle())

         Button("Delete") { }
             .buttonStyle(DestructiveButtonStyle())
     }
 }
 ```

 Confirmation Dialog:
 ```
 @State private var showConfirm = false

 Button("Delete") {
     showConfirm = true
 }

 ConfirmationDialog(
     isPresented: $showConfirm,
     title: "Delete Bill?",
     message: "This action cannot be undone",
     confirmTitle: "Delete",
     confirmAction: { deleteBill() },
     isDestructive: true
 )
 ```

 Loading Overlay:
 ```
 @State private var isLoading = false

 VStack {
     // Content
 }
 .loadingOverlay(isPresented: $isLoading, message: "Saving...")
 ```

 Using View Extension:
 ```
 ContentView()
     .customModal(isPresented: $showModal) {
         ModalContentView()
     }
 ```

 */
