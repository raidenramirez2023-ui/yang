# Yang Chow Restaurant Management System - Clean Architecture

## 📁 Project Structure

```
lib/
├── 📄 main.dart                    # App entry point
├── 📄 firebase_options.dart         # Firebase configuration
├── 📄 globals.dart                # Global variables
├── 📁 core/                      # Core utilities and themes
│   ├── 📄 app_theme.dart          # App theme and colors
│   └── 📄 responsive_utils.dart  # Responsive utilities
├── 📁 features/                  # Feature-based organization
│   ├── 📁 auth/                 # Authentication features
│   │   ├── 📄 login_page.dart
│   │   └── 📄 forgot_password_page.dart
│   ├── 📁 admin/                # Admin-specific features
│   │   ├── 📄 admin_main_page.dart
│   │   ├── 📄 inventory_management.dart
│   │   ├── 📄 sales_report_page.dart
│   │   ├── 📄 user_management.dart
│   │   └── 📄 settings.dart
│   └── 📁 staff/                # Staff-specific features
│       └── 📄 staff_dashboard.dart
└── 📁 shared/                    # Shared components and constants
    ├── 📁 constants/
    │   └── 📄 app_constants.dart  # App-wide constants
    └── 📁 widgets/
        ├── 📄 shared_pos_widget.dart
        └── 📄 order_list_panel.dart
```

## 🏗️ Architecture Principles

### 📦 Feature-Based Structure
- **features/**: Contains all feature-related code
- **auth/**: Login, forgot password, registration
- **admin/**: Admin dashboard, inventory, reports, user management
- **staff/**: Staff dashboard and POS functionality

### 🔧 Core Components
- **core/**: Shared utilities, themes, and helper functions
- **shared/**: Reusable widgets and constants

### 🎨 Clean Code Benefits
1. **Separation of Concerns**: Each feature has its own folder
2. **Scalability**: Easy to add new features
3. **Maintainability**: Clear structure for navigation
4. **Reusability**: Shared components in dedicated folders
5. **Team Collaboration**: Multiple developers can work on different features

## 🚀 Routes Structure
- `/` - Login page
- `/forgot-password` - Forgot password
- `/dashboard` - Admin main page
- `/staff-dashboard` - Staff dashboard

## 🎯 Key Improvements Made
✅ Removed redundant files (admin_dashboard.dart, register_page.dart)
✅ Organized imports with clean paths
✅ Created constants file for magic strings
✅ Feature-based folder structure
✅ Clean main.dart with minimal imports
✅ Proper naming conventions

## 📱 Responsive Design
- Mobile-first approach
- Adaptive layouts for tablets and desktops
- Consistent breakpoints across features

## 🔥 Firebase Integration
- Authentication with role-based access
- Firestore for user data
- Real-time updates support
