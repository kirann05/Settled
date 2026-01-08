# Settled Design System

Comprehensive, accessible UI design system based on modern best practices and OKLCH color space.

## Table of Contents
1. [Quick Start](#quick-start)
2. [Color System](#color-system)
3. [Typography](#typography)
4. [Spacing & Layout](#spacing--layout)
5. [Component Catalog](#component-catalog)
6. [Animations](#animations)
7. [Accessibility Guidelines](#accessibility-guidelines)
8. [Best Practices](#best-practices)
9. [Migration Guide](#migration-guide)
10. [Troubleshooting](#troubleshooting)

---

## Quick Start

### 1. Import and Use
All design system components are available automatically when you import SwiftUI in your project. No additional imports needed.

```swift
import SwiftUI  // Design system is available!
```

### 2. Basic Usage Examples

#### Colors
```swift
// Background depth levels
.background(Color.adaptiveDepth0)    // Base background
.background(Color.adaptiveDepth1)    // Raised containers
.background(Color.adaptiveDepth2)    // Card surfaces
.background(Color.adaptiveDepth3)    // Elevated elements

// Text hierarchy
.foregroundColor(.adaptiveTextPrimary)    // 95% opacity
.foregroundColor(.adaptiveTextSecondary)  // 70% opacity
.foregroundColor(.adaptiveTextTertiary)   // 50% opacity
```

#### Typography
```swift
// Using font scale
Text("Title").font(.h1Dynamic)
Text("Subtitle").font(.h3Dynamic)
Text("Body").font(.bodyDynamic)

// Using semantic modifiers (recommended)
Text("Welcome").heading1()
Text("Description").bodyStyle()
Text("Timestamp").captionStyle()
```

#### Spacing
```swift
// Base spacing scale
VStack(spacing: .spacingLG) { }     // 24px spacing
.padding(.spacingMD)                 // 16px padding

// Semantic spacing
VStack { }
    .padding(.paddingCard)           // 24px all sides
    .padding(.paddingScreen)         // 16px all sides
```

#### Components
```swift
// Buttons
Button("Submit") { }
    .buttonStyle(PrimaryButtonStyle())

// Cards
CardView {
    VStack {
        Text("Content")
    }
}

// Text Fields
StyledTextField(
    label: "Email",
    placeholder: "you@example.com",
    text: $email
)
```

---

## Color System

### OKLCH-Based Depth Levels
Perceptually uniform color system that automatically adapts to light/dark mode.

| Color | Usage | Light Mode | Dark Mode |
|-------|-------|-----------|-----------|
| `.adaptiveDepth0` | Base background | RGB(0,0,0) | RGB(26,26,26) |
| `.adaptiveDepth1` | Raised containers | RGB(13,13,13) | RGB(38,38,38) |
| `.adaptiveDepth2` | Card surfaces | RGB(26,26,26) | RGB(51,51,51) |
| `.adaptiveDepth3` | Elevated elements | RGB(38,38,38) | RGB(64,64,64) |

### Text Hierarchy
| Color | Opacity | Usage |
|-------|---------|-------|
| `.adaptiveTextPrimary` | 95% | Headings, important text |
| `.adaptiveTextSecondary` | 70% | Body text, descriptions |
| `.adaptiveTextTertiary` | 50% | Captions, metadata |

### Accent Color
- `.accentColor` - Primary brand color for CTAs, highlights, and interactive elements
- Automatically set from Assets.xcassets or system accent

### Examples
```swift
// Depth-based backgrounds
VStack {
    Text("Card Content")
}
.background(Color.adaptiveDepth2)
.cornerRadius(.cornerRadiusMedium)

// Text hierarchy
VStack(alignment: .leading) {
    Text("Bill Summary").foregroundColor(.adaptiveTextPrimary)
    Text("Total: $45.00").foregroundColor(.adaptiveTextSecondary)
    Text("Updated 2m ago").foregroundColor(.adaptiveTextTertiary)
}
```

---

## Typography

### Type Scale

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| `.h1Dynamic` | 40pt | Bold | Screen titles, main headings |
| `.h2Dynamic` | 32pt | Bold | Section titles, important headings |
| `.h3Dynamic` | 24pt | Semibold | Subsection titles, card headers |
| `.h4Dynamic` | 20pt | Semibold | Minor headings, label groups |
| `.bodyDynamic` | 16pt | Regular | Main content, default text |
| `.smallDynamic` | 14pt | Regular | Secondary content, metadata |
| `.captionDynamic` | 12pt | Regular | Fine print, timestamps, captions |

### Semantic Modifiers (Recommended)

```swift
// Heading styles
Text("Welcome to Settled").heading1()
Text("Recent Bills").heading2()
Text("Today's Activity").heading3()
Text("Bill Details").heading4()

// Body and supplementary
Text("This is the main content").bodyStyle()
Text("Additional information").smallStyle()
Text("Created 5 minutes ago").captionStyle()
```

### Dynamic Type Support
All typography automatically scales with iOS accessibility text size settings:
- Users can adjust text size in Settings → Accessibility → Display & Text Size
- Components maintain proper hierarchy at all sizes
- Use `.font(.h1Dynamic)` instead of `.font(.h1)` for accessibility

```swift
// Accessible (scales with user settings)
Text("Welcome").font(.h1Dynamic)

// Fixed size (use sparingly, less accessible)
Text("Logo").font(.h1)
```

---

## Spacing & Layout

### Base Spacing Scale
Based on 4px/8px grid system for visual harmony:

| Value | Size | Usage |
|-------|------|-------|
| `.spacingXS` | 4px | Tight element spacing, icon padding |
| `.spacingSM` | 8px | Label-to-control spacing, compact layouts |
| `.spacingMD` | 16px | Standard padding, element separation (default) |
| `.spacingLG` | 24px | Section spacing, card internal padding |
| `.spacingXL` | 32px | Major section breaks, screen padding |
| `.spacing2XL` | 48px | Large section separation, feature spacing |
| `.spacing3XL` | 64px | Major visual breaks, hero sections |

### Semantic Spacing Values
Context-specific spacing for common patterns:

| Value | Size | Usage |
|-------|------|-------|
| `.paddingCard` | 24px | Card interior padding |
| `.paddingScreen` | 16px | Screen edge padding |
| `.paddingSection` | 32px | Major section padding |

### Corner Radius
| Value | Size | Usage |
|-------|------|-------|
| `.cornerRadiusSmall` | 8px | Buttons, small cards, inputs |
| `.cornerRadiusMedium` | 12px | Cards, containers, medium UI elements |
| `.cornerRadiusLarge` | 16px | Large cards, modals, prominent containers |

### Edge Insets Presets
```swift
// Pre-configured padding sets
.listRowInsets(.cardPadding)      // 24px all sides
.listRowInsets(.screenPadding)    // 16px all sides
.listRowInsets(.sectionPadding)   // 32px vertical, 16px horizontal
```

### Examples
```swift
// Spacing scale
VStack(spacing: .spacingLG) {
    Text("Item 1")
    Text("Item 2")
}
.padding(.spacingMD)

// Semantic padding
VStack {
    Text("Card Content")
}
.padding(.paddingCard)
.background(Color.adaptiveDepth2)
.cornerRadius(.cornerRadiusMedium)

// Screen layout
ScrollView {
    VStack(spacing: .paddingSection) {
        SectionOne()
        SectionTwo()
    }
    .padding(.paddingScreen)
}
```

---

## Component Catalog

### Buttons

#### Primary Button
**Usage**: Main CTAs, important actions, form submissions

```swift
Button("Submit") {
    submitForm()
}
.buttonStyle(PrimaryButtonStyle())
```

#### Secondary Button
**Usage**: Secondary actions, cancel buttons, alternative choices

```swift
Button("Cancel") {
    dismissView()
}
.buttonStyle(SecondaryButtonStyle())
```

#### Tertiary Button
**Usage**: Tertiary actions, links, inline actions

```swift
Button("Learn More") {
    showInfo()
}
.buttonStyle(TertiaryButtonStyle())
```

#### Destructive Button
**Usage**: Delete actions, destructive confirmations

```swift
Button("Delete Bill") {
    deleteBill()
}
.buttonStyle(DestructiveButtonStyle())
```

### Cards

#### Basic Card
**Usage**: Content containers, list items, grouped content

```swift
CardView {
    VStack(alignment: .leading, spacing: .spacingMD) {
        Text("Bill Summary").heading3()
        Text("Total: $124.50").bodyStyle()
    }
}
```

#### Elevated Card
**Usage**: Interactive cards, prominent content, feature sections

```swift
ElevatedCard(depth: 2) {
    // Card content with hover effects
}
```

#### Compact Card
**Usage**: List rows, compact displays, dense layouts

```swift
CompactCard {
    HStack {
        Text("Item")
        Spacer()
        Text("$10.00")
    }
}
```

#### Interactive Card
**Usage**: Navigable cards, selectable items, interactive content

```swift
InteractiveCard(action: { navigateToDetail() }) {
    HStack {
        Text("View Details")
        Spacer()
        Image(systemName: "chevron.right")
    }
}
```

### Text Fields

#### Basic Text Field
```swift
@State private var username = ""

StyledTextField(
    label: "Username",
    placeholder: "Enter your username",
    text: $username
)
```

#### Email/Password Fields
```swift
@State private var email = ""
@State private var password = ""

StyledTextField(
    label: "Email",
    placeholder: "you@example.com",
    text: $email,
    keyboardType: .emailAddress,
    autocapitalization: .never
)

StyledTextField(
    label: "Password",
    placeholder: "Enter password",
    text: $password,
    isSecure: true
)
```

#### Text Field with Validation
```swift
@State private var email = ""
@State private var emailError: String? = nil

StyledTextFieldWithError(
    label: "Email",
    placeholder: "you@example.com",
    text: $email,
    errorMessage: emailError,
    keyboardType: .emailAddress
)
```

#### Search Field
```swift
@State private var searchText = ""

SearchField(
    placeholder: "Search bills...",
    text: $searchText
)
```

### Toggles

#### Styled Toggle
```swift
@State private var notificationsEnabled = true

StyledToggle(
    label: "Enable Notifications",
    isOn: $notificationsEnabled,
    description: "Receive push notifications for bill updates"
)
```

#### Compact Toggle
```swift
CompactToggle(
    label: "Dark Mode",
    isOn: $darkMode
)
```

#### Icon Toggle
```swift
IconToggle(
    label: "Push Notifications",
    icon: "bell.fill",
    isOn: $pushEnabled,
    iconColor: .accentColor
)
```

#### Card Toggle
```swift
CardToggle(
    title: "Premium Features",
    description: "Enable advanced bill splitting",
    isOn: $premiumEnabled,
    icon: "star.fill"
)
```

### Modals

#### Standard Modal
```swift
@State private var showModal = false

CustomModal(isPresented: $showModal) {
    VStack(spacing: .spacingLG) {
        Text("Modal Title").heading2()
        Text("Modal content here").bodyStyle()
        Button("Confirm") {
            showModal = false
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}
```

#### Bottom Sheet
```swift
@State private var showSheet = false

BottomSheet(isPresented: $showSheet) {
    VStack(spacing: .spacingMD) {
        Button("Option 1") { }
        Button("Option 2") { }
    }
}
```

#### Confirmation Dialog
```swift
@State private var showConfirm = false

ConfirmationDialog(
    isPresented: $showConfirm,
    title: "Delete Bill?",
    message: "This action cannot be undone",
    confirmTitle: "Delete",
    confirmAction: { deleteBill() },
    isDestructive: true
)
```

#### Loading Modal
```swift
@State private var isLoading = false

LoadingModal(
    isPresented: $isLoading,
    message: "Processing..."
)
```

### Headers & Text

#### Heading Text
```swift
HeadingText("Main Screen Title")
```

#### Body Text
```swift
BodyText("This is standard body text for main content.")
```

#### Section Header
```swift
SectionHeader(title: "Recent Activity")

// With action button
SectionHeader(
    title: "Recent Bills",
    actionTitle: "View All",
    action: { print("View All tapped") }
)
```

### List Rows

#### Standard List Row
```swift
StandardListRow(
    title: "Profile Settings",
    subtitle: "Manage your account",
    systemIcon: "person.circle.fill"
)
```

#### Badge List Row
```swift
BadgeListRow(
    title: "Notifications",
    subtitle: "3 new messages",
    systemIcon: "bell.fill",
    badgeCount: 3
)
```

#### Toggle List Row
```swift
@State private var pushEnabled = true

ToggleListRow(
    title: "Push Notifications",
    subtitle: "Receive real-time updates",
    systemIcon: "bell.badge.fill",
    isOn: $pushEnabled
)
```

#### Action List Row
```swift
ActionListRow(
    title: "Delete Account",
    subtitle: "Permanently remove your data",
    systemIcon: "trash.fill",
    isDestructive: true,
    action: { deleteAccount() }
)
```

---

## Animations

### Spring Animations

| Animation | Response | Damping | Usage |
|-----------|----------|---------|-------|
| `.smoothSpring` | 0.3s | 0.7 | Quick interactions, button presses, toggles |
| `.gentleSpring` | 0.4s | 0.8 | Card animations, drag gestures, fluid transitions |
| `.bouncySpring` | 0.5s | 0.6 | Celebrations, success states, playful interactions |
| `.snappySpring` | 0.25s | 0.9 | Precise interactions, picker selections, snap-to-grid |

### Ease Animations

| Animation | Duration | Usage |
|-----------|----------|-------|
| `.smoothEaseOut` | 200ms | Button hovers, state changes, general transitions |
| `.mediumEaseOut` | 300ms | Modal presentations, sheet transitions |
| `.longEaseOut` | 400ms | Page transitions, complex animations |

### Specialized Animations

| Animation | Type | Usage |
|-----------|------|-------|
| `.buttonPress` | Ease (150ms) | Button tap feedback |
| `.cardFlip` | Spring | Card rotation and flips |
| `.modalPresent` | EaseInOut (350ms) | Modal/sheet appearance |
| `.loadingPulse` | Repeating | Loading indicators |

### Examples

```swift
// Button press feedback
Button("Tap Me") {
    isPressed.toggle()
}
.scaleEffect(isPressed ? 0.95 : 1.0)
.animation(.buttonPress, value: isPressed)

// Gentle spring transition
Circle()
    .offset(y: isExpanded ? 0 : 100)
    .animation(.gentleSpring, value: isExpanded)

// Modal presentation
.sheet(isPresented: $showModal) {
    ModalView()
}
.animation(.modalPresent, value: showModal)
```

---

## Accessibility Guidelines

### WCAG AA Compliance
- **Text Contrast**: All text colors meet WCAG AA standards (4.5:1 for body text, 3:1 for large text)
- **Touch Targets**: All interactive elements have minimum 44x44pt touch targets
- **Focus States**: Clear visual indicators for keyboard navigation
- **Color Independence**: Color is never the only means of conveying information

### VoiceOver Support

#### Accessibility Labels
```swift
Button("Delete") { }
    .accessibilityLabel("Delete bill")
    .accessibilityHint("Permanently deletes this bill")
```

#### Accessibility Grouping
```swift
CardView {
    VStack {
        Text("Bill Total")
        Text("$45.00")
    }
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Bill total: 45 dollars")
```

#### Hidden Decorative Elements
```swift
Image(systemName: "chevron.right")
    .accessibilityHidden(true)  // Hide decorative icons
```

### Dynamic Type
All typography automatically scales with user preferences:
- Always use `.h1Dynamic`, `.bodyDynamic`, etc. for text that should scale
- Test with Settings → Accessibility → Display & Text Size → Larger Text
- Layouts should adapt gracefully to larger text sizes

### Reduced Motion
Respect user's reduced motion preferences:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Conditionally disable animations
.animation(reduceMotion ? .none : .gentleSpring, value: isAnimated)
```

### Best Practices
1. **Always provide accessibility labels** for interactive elements
2. **Use semantic HTML/SwiftUI elements** (Button, Toggle, etc.)
3. **Test with VoiceOver** regularly during development
4. **Support Dynamic Type** for all user-facing text
5. **Respect reduced motion** preferences for animations
6. **Provide text alternatives** for icons and images

---

## Best Practices

### Do ✅

1. **Use Adaptive Colors**
   ```swift
   .background(Color.adaptiveDepth2)  // Automatic light/dark mode
   ```

2. **Reference Spacing Scale**
   ```swift
   .padding(.spacingMD)  // Instead of .padding(16)
   ```

3. **Apply Dynamic Type**
   ```swift
   Text("Title").font(.h1Dynamic)  // Scales with accessibility settings
   ```

4. **Use Semantic Modifiers**
   ```swift
   Text("Welcome").heading1()  // Instead of manual font + color
   ```

5. **Leverage Component Library**
   ```swift
   Button("Submit") { }.buttonStyle(PrimaryButtonStyle())
   ```

6. **Maintain Accessibility**
   ```swift
   .accessibilityLabel("Delete bill")
   .accessibilityHint("Permanently removes this bill")
   ```

### Don't ❌

1. **Hardcode RGB/Hex Colors**
   ```swift
   // ❌ Don't
   .background(Color(red: 0.1, green: 0.1, blue: 0.1))

   // ✅ Do
   .background(Color.adaptiveDepth1)
   ```

2. **Use Arbitrary Spacing**
   ```swift
   // ❌ Don't
   .padding(23)

   // ✅ Do
   .padding(.spacingLG)
   ```

3. **Create Fixed-Size Fonts**
   ```swift
   // ❌ Don't
   .font(.system(size: 24))

   // ✅ Do
   .font(.h3Dynamic)
   ```

4. **Skip Accessibility Features**
   ```swift
   // ❌ Don't
   Button("Delete") { deleteBill() }

   // ✅ Do
   Button("Delete") { deleteBill() }
       .accessibilityLabel("Delete bill")
       .accessibilityHint("Permanently deletes this bill")
   ```

5. **Use Linear Animations**
   ```swift
   // ❌ Don't
   .animation(.linear(duration: 0.3))

   // ✅ Do
   .animation(.gentleSpring)
   ```

### Anti-Patterns to Avoid

1. **Mixing Spacing Systems**: Don't combine design system spacing with arbitrary values
2. **Inconsistent Typography**: Always use the type scale, don't create one-off font sizes
3. **Manual Light/Dark Mode**: Use adaptive colors instead of manual color scheme checks
4. **Ignoring Accessibility**: Accessibility is not optional, it's a requirement
5. **Overusing Elevation**: Use depth levels purposefully, not for every element

---

## Migration Guide

### For New Developers

#### Step 1: Understand the Foundations
1. Review [Color System](#color-system) - depth levels and text hierarchy
2. Study [Typography](#typography) - type scale and semantic modifiers
3. Learn [Spacing & Layout](#spacing--layout) - spacing scale and corner radius

#### Step 2: Explore Components
1. Browse [Component Catalog](#component-catalog)
2. Run `DesignSystemPreview.swift` to see interactive examples
3. Experiment with different component variations

#### Step 3: Build Your First View
```swift
import SwiftUI

struct MyFirstView: View {
    @State private var email = ""

    var body: some View {
        ScreenContainer {
            VStack(spacing: .spacingLG) {
                // Header
                Text("Welcome").heading1()
                Text("Please sign in to continue").bodyStyle()

                // Form
                StyledTextField(
                    label: "Email",
                    placeholder: "you@example.com",
                    text: $email,
                    keyboardType: .emailAddress
                )

                // Action
                Button("Sign In") {
                    // Handle sign in
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
    }
}
```

### For Existing Codebase

#### Step 1: Gradual Adoption
- Start with new screens using the design system
- Refactor high-traffic screens first
- Don't try to migrate everything at once

#### Step 2: Component Replacement Guide

| Old Pattern | New Component |
|-------------|---------------|
| Custom button with styling | `PrimaryButtonStyle()`, `SecondaryButtonStyle()` |
| VStack with background | `CardView { }`, `ElevatedCard { }` |
| TextField with styling | `StyledTextField()`, `SearchField()` |
| Toggle with custom style | `StyledToggle()`, `CompactToggle()` |
| Custom modal | `CustomModal()`, `BottomSheet()` |

#### Step 3: Color Migration
```swift
// Before
.background(Color(red: 0.1, green: 0.1, blue: 0.1))
.foregroundColor(Color.white)

// After
.background(Color.adaptiveDepth1)
.foregroundColor(.adaptiveTextPrimary)
```

#### Step 4: Typography Migration
```swift
// Before
Text("Title")
    .font(.system(size: 32, weight: .bold))
    .foregroundColor(.white)

// After
Text("Title").heading2()
```

#### Step 5: Spacing Migration
```swift
// Before
VStack(spacing: 24) {
    // content
}
.padding(16)

// After
VStack(spacing: .spacingLG) {
    // content
}
.padding(.paddingScreen)
```

---

## Troubleshooting

### Common Issues

#### 1. Colors Not Adapting to Dark Mode
**Problem**: Colors don't change in dark mode
**Solution**: Use `.adaptiveDepth*` and `.adaptiveText*` colors instead of hardcoded values

```swift
// ❌ Wrong
.background(Color.black)

// ✅ Correct
.background(Color.adaptiveDepth0)
```

#### 2. Text Not Scaling with Dynamic Type
**Problem**: Text size doesn't change with accessibility settings
**Solution**: Use dynamic fonts (`.h1Dynamic`, `.bodyDynamic`)

```swift
// ❌ Wrong
.font(.system(size: 16))

// ✅ Correct
.font(.bodyDynamic)
```

#### 3. Inconsistent Spacing
**Problem**: Elements have misaligned spacing
**Solution**: Use the spacing scale consistently

```swift
// ❌ Wrong
VStack(spacing: 20) {
    // Mixed spacing values
}
.padding(15)

// ✅ Correct
VStack(spacing: .spacingLG) {
    // Consistent spacing
}
.padding(.paddingScreen)
```

#### 4. Animations Not Working
**Problem**: Animations appear broken or jerky
**Solution**: Use spring animations and bind to specific values

```swift
// ❌ Wrong
.animation(.linear(duration: 0.3))

// ✅ Correct
.animation(.gentleSpring, value: isAnimated)
```

#### 5. Accessibility Warnings
**Problem**: VoiceOver not reading elements correctly
**Solution**: Add proper accessibility labels and hints

```swift
// ❌ Wrong
Button("Delete") { }

// ✅ Correct
Button("Delete") { }
    .accessibilityLabel("Delete bill")
    .accessibilityHint("Permanently deletes this bill")
```

### Performance Issues

#### Large Lists
Use `LazyVStack` or `List` for long scrolling content:
```swift
LazyVStack(spacing: .spacingMD) {
    ForEach(items) { item in
        CardView {
            // Content
        }
    }
}
```

#### Heavy Animations
For complex views, consider disabling animations for reduced motion:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

.animation(reduceMotion ? .none : .gentleSpring, value: state)
```

### Getting Help

1. **Check DesignSystemPreview.swift** - Interactive examples of all components
2. **Review Component Documentation** - Each component has usage examples in comments
3. **Refer to This README** - Comprehensive guide to all design system features
4. **Test in Preview** - Use SwiftUI previews for rapid iteration

---

## Design System Benefits

### 1. Consistency
- Unified visual language across all screens
- Predictable user experience
- Reduced design debt over time

### 2. Maintainability
- Centralized styling reduces code duplication
- Single source of truth for design decisions
- Easy to update global styles

### 3. Accessibility
- Built-in Dynamic Type support
- WCAG AA compliant color contrast
- VoiceOver optimized components
- Reduced motion support

### 4. Dark Mode
- Automatic light/dark mode adaptation
- OKLCH-based perceptually uniform colors
- No manual theme switching required

### 5. Performance
- Optimized animations with spring curves
- Efficient rendering with proper view hierarchy
- Reduced unnecessary re-renders

### 6. Developer Experience
- Clear, semantic API surface
- Comprehensive documentation
- Interactive preview screens
- Easy to learn and use

---

## Version History

**v1.0.0** (2025-10-06)
- Complete design system implementation
- Foundation: Colors, Typography, Spacing, Animations
- Components: Buttons, Cards, Text Fields, Toggles, Modals, Headers, List Rows
- Full accessibility support with WCAG AA compliance
- Interactive preview screens for all components
- Comprehensive documentation

---

## Related Files

- **Design System Preview**: `DesignSystemPreview.swift` - Interactive component showcase
- **Quick Reference**: `QUICK_REFERENCE.md` - One-page cheat sheet
- **UI Design Principles**: `/UI - Design Best Practices/ui-design-principles-general.md`
- **SwiftUI Patterns**: `/UI - Design Best Practices/ui-design-principles-swiftui.md`
- **Task Tracking**: `/SettledApp/tasks.md` (Epic 12: UI Design System)

---

**Last Updated**: 2025-10-06
**Status**: Complete ✅
**Maintained By**: Settled Development Team
