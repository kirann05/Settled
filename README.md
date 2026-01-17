# Settled iOS App

A native iOS app built with SwiftUI for splitting bills and tracking expenses with friends and family. Settled helps groups split restaurant bills, track who owes whom, and settle up expenses seamlessly.

## 📱 Features

### Core Features

- **Home Dashboard**: Real-time balance tracking showing who owes you money and who you owe
- **Receipt Scanning**: 
  - Take photos of receipts using camera
  - Upload from photo library
  - Manual bill entry
  - OCR text extraction using Apple Vision framework
  - Smart receipt classification (food, tax, tip, etc.) using multiple strategies
- **Bill Splitting**: 
  - Assign items to multiple participants
  - Automatic calculation of who owes what
  - Support for tax and tip distribution
  - Real-time balance updates
- **Bill Management**:
  - Create bills from scanned receipts or manual entry
  - Edit existing bills (with conflict detection)
  - Soft delete bills (preserves history)
  - View detailed bill breakdowns
- **History**: 
  - Complete transaction history
  - Bill activity tracking
  - Filter by date, participant, amount
- **Profile & Settings**:
  - User profile management
  - Account management (delete account)

### Advanced Features

- **Real-time Synchronization**: Firebase Firestore listeners for instant updates across devices
- **Session Recovery**: Automatic recovery of incomplete bill creation sessions (24-hour expiration)
- **Conflict Detection**: Optimistic locking prevents concurrent edit conflicts
- **Smart Classification**: Multi-strategy receipt classification (geometric, pattern, price relationships, Gemini AI)
- **Design System**: Comprehensive, accessible UI design system with adaptive colors and dynamic type

## 🚀 Getting Started

### Prerequisites

- **Xcode**: 15.0 or later
- **iOS**: 17.0 or later
- **macOS**: 14.0 or later (for development)
- **Firebase Account**: For backend services
- **Google Sign-In**: Configured in Firebase Console

### Installation

1. **Clone the repository**
   ```bash
   git clone <https://github.com/kirann05/Settled.git>
   cd SettledApp
   ```

2. **Configure Firebase**
   - Add `GoogleService-Info.plist` to `Settled/` directory
   - Ensure Firebase project is configured in Firebase Console
   - Deploy Firestore security rules from `infrastructure/firebase/firestore.rules`

3. **Configure API Keys** (Optional, for Gemini AI classification)
   
   **Development Method** (DEBUG builds only):
   - `DevelopmentConfig.swift` can auto-populate the API key in Keychain for testing
   - The API key is stored securely in iOS Keychain
   - ⚠️ **Important**: Remove `DevelopmentConfig.swift` before production deployment
   
   **Note**: `AdvancedSettingsView` and `GeminiSettingsView` exist in the codebase but may not be accessible from the Profile screen in the current UI implementation. For production, users would need to add their API key via the Settings UI if/when that navigation is implemented.

4. **Open in Xcode**
   ```bash
   open Settled.xcodeproj
   ```

5. **Build and Run**
   - Select target device or simulator
   - Press `Cmd + R` to build and run

### Firebase Setup

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Create new project or use existing
   - Add iOS app with bundle ID matching your Xcode project

2. **Download Configuration**
   - Download `GoogleService-Info.plist`
   - Add to `Settled/` directory in Xcode

3. **Enable Services**
   - **Authentication**: Enable Google Sign-In
   - **Firestore**: Create database in production mode

4. **Deploy Security Rules**
   ```bash
   cd infrastructure/scripts
   ./deploy-firestore-rules.sh
   ```

5. **Create Firestore Indexes**
   - Deploy indexes from `infrastructure/firebase/firestore.indexes.json`

## 📁 Project Structure

```
SettledApp/
├── Settled/                    # Main app source code
│   ├── SettledApp.swift       # App entry point (@main)
│   ├── ContentView.swift         # Main navigation container
│   ├── Models/                    # Data models & business logic
│   │   ├── DataModels.swift      # Core data structures (Bill, BillItem, etc.)
│   │   ├── AuthViewModel.swift   # Authentication state management
│   │   ├── Services/              # Business logic services
│   │   │   ├── BillService.swift # Bill CRUD operations
│   │   │   ├── OCRService.swift  # Receipt scanning
│   │   │   ├── BillCalculator.swift # Balance calculations
│   │   │   ├── ContactsManager.swift # Contact management
│   │   │   └── ConflictDetectionService.swift # Edit conflict detection
│   │   └── Classification/       # Receipt classification system
│   │       ├── ReceiptClassifier.swift
│   │       ├── GeminiClassificationStrategy.swift
│   │       └── ...
│   ├── Views/                     # Screen-level views
│   │   ├── AuthView.swift        # Login/signup
│   │   ├── ScanView.swift        # Receipt scanning
│   │   ├── BillEdit/             # Bill editing flow
│   │   └── Settings/             # Settings screens
│   ├── Components/               # Reusable UI components
│   │   ├── Bill/                # Bill-related components
│   │   ├── Contact/             # Contact components
│   │   └── Item/                # Item components
│   ├── DesignSystem/            # Design system (colors, typography, etc.)
│   ├── Services/                # App-level services
│   │   └── DeepLinkCoordinator.swift
│   ├── Utilities/               # Helper utilities
│   └── Assets.xcassets/         # Images, colors, icons
├── architecture/                 # Architecture documentation
│   ├── bill-services-overview.md
│   └── data-flow-diagram.md
├── infrastructure/               # Infrastructure & deployment
│   ├── firebase/                # Firebase configuration
│   │   ├── firestore.rules      # Security rules
│   │   └── firestore.indexes.json
│   └── scripts/                 # Deployment scripts
├── SettledTests/             # Unit tests
└── README.md                    # This file
```

## 🏗️ Architecture

Settled follows **MVVM (Model-View-ViewModel)** architecture pattern:

- **Models**: Data structures (`Bill`, `BillItem`, `BillParticipant`)
- **Views**: SwiftUI views (`UIHomeScreen`, `UIScanScreen`, etc.)
- **ViewModels**: ObservableObjects (`AuthViewModel`, `BillManager`)
- **Services**: Business logic layer (`BillService`, `OCRService`, etc.)

### Key Architectural Patterns

1. **Separation of Concerns**
   - `BillManager`: Read-only real-time state (Firestore listeners)
   - `BillService`: Write operations (CRUD with validation)

2. **State Management**
   - SwiftUI `@StateObject` and `@ObservedObject` for reactive UI
   - `@Published` properties trigger automatic view updates
   - Environment objects for app-wide state

3. **Data Flow**
   - Firestore listeners → `BillManager` → SwiftUI views (read)
   - User actions → Views → Services → Firestore (write)
   - Real-time updates via Firestore snapshot listeners

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture documentation.

## 🔄 User Workflows

### Creating a Bill

1. **Start New Bill**: Tap "Add" button on home screen
2. **Scan or Enter**:
   - **Scan**: Take photo or upload from library → OCR extraction → Review items
   - **Manual**: Enter items manually with name and price
3. **Assign Items**: Select participants for each item
4. **Review Summary**: Check totals, who owes what
5. **Create Bill**: Save to Firestore

### Editing a Bill

1. **Open Bill**: Navigate to bill from History
2. **Edit**: Modify items, participants, amounts
3. **Conflict Detection**: System detects concurrent edits
4. **Save**: Update with optimistic locking

### Viewing Balances

- **Home Screen**: Shows net balances (owed/owing)
- **Real-time Updates**: Automatically updates when bills change
- **Per-Person Breakdown**: See individual debts

See [USER_WORKFLOW.md](./USER_WORKFLOW.md) for complete user workflow documentation.

## 🛠️ Technology Stack

### Core Technologies

- **SwiftUI**: Declarative UI framework
- **Firebase**:
  - **Firestore**: Real-time database
  - **Authentication**: Google Sign-In
- **Apple Vision**: OCR text recognition
- **Natural Language**: Text processing

### Key Frameworks

- `Combine`: Reactive programming
- `Async/Await`: Modern concurrency
- `OSLog`: Structured logging

## 📚 Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)**: Detailed architecture documentation
- **[USER_WORKFLOW.md](./USER_WORKFLOW.md)**: User workflows and feature documentation
- **[Design System](./Settled/DesignSystem/README.md)**: UI design system guide
- **[Bill Services Overview](./architecture/bill-services-overview.md)**: Service layer documentation
- **[Data Flow Diagrams](./architecture/data-flow-diagram.md)**: Visual data flow documentation

## 🔐 Security

- **Firestore Security Rules**: Enforce access control at database level
- **Authentication**: Google Sign-In with Firebase Auth
- **Authorization**: Only bill creators can edit/delete bills
- **Data Validation**: Server-side and client-side validation
- **Soft Deletion**: Bills marked deleted, not hard-deleted

## 🧪 Testing

- **Unit Tests**: `SettledTests/` directory
- **Test Coverage**: Classification strategies, bill calculations
- **Manual Testing**: Use Firebase emulator for local testing

## 🚢 Deployment

### Prerequisites

- Firebase project configured
- Firestore security rules deployed
- Firestore indexes created

### Build for Production

1. **Update Version**: Update version in Xcode project settings
2. **Archive**: Product → Archive in Xcode
3. **Distribute**: Upload to App Store Connect
4. **TestFlight**: Test with beta testers
5. **Release**: Submit for App Store review

## 🤝 Contributing

1. Follow SwiftUI best practices
2. Use the design system for UI components
3. Write tests for new features
4. Update documentation for architectural changes
5. Follow MVVM pattern for new screens

## 📝 License

This project is proprietary software. All rights reserved.





---


