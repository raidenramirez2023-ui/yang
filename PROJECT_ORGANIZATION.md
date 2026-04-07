# Yang Chow - Project Organization

## Overview
The Yang Chow Flutter project has been reorganized into a hierarchical folder structure to improve maintainability and team scalability. All page files are now organized by role/feature domain while maintaining a single package import pattern.

## Folder Structure

```
lib/
├── pages/
│   ├── admin/                          # Admin dashboard and management
│   │   ├── admin_announcements_page.dart
│   │   ├── admin_chat_page.dart
│   │   ├── admin_dashboard.dart
│   │   ├── admin_main_page.dart
│   │   ├── admin_reservations_page.dart
│   │   ├── pagsanjaninv_dashboard.dart
│   │   ├── sales_report_page.dart
│   │   └── user_management.dart
│   │
│   ├── staff/                          # Staff operations and inventory
│   │   ├── staff_login_page.dart
│   │   ├── staff_dashboard.dart
│   │   ├── chef_dashboard.dart
│   │   ├── staff_order_history_page.dart
│   │   ├── inventory_management.dart
│   │   ├── inventory_room_page.dart
│   │   └── inventory_forecast_page.dart
│   │
│   ├── customer/                       # Customer-facing features
│   │   ├── customer_chat_page.dart
│   │   ├── customer_dashboard.dart
│   │   ├── customer_registration_page.dart
│   │   ├── customer_reviews_page.dart
│   │   ├── edit_profile_page.dart
│   │   └── payment_page.dart
│   │
│   ├── login_page.dart                 # Shared auth - Customer login with Remember Me
│   ├── forgot_password_page.dart       # Shared auth - Password recovery with Remember Me
│   ├── landing_page.dart               # Shared - Landing page
│   └── update_password_page.dart       # Shared auth - Password update
│
├── services/                           # Business logic unchanged
├── utils/                              # Utilities unchanged
├── widgets/                            # Widgets unchanged
├── models/                             # Data models unchanged
└── main.dart                           # App entry point
```

## Import Pattern

All imports follow a consistent package-based pattern:

```dart
// Admin pages
import 'package:yang_chow/pages/admin/admin_dashboard.dart';
import 'package:yang_chow/pages/admin/admin_main_page.dart';
import 'package:yang_chow/pages/admin/user_management.dart';

// Staff pages
import 'package:yang_chow/pages/staff/staff_dashboard.dart';
import 'package:yang_chow/pages/staff/inventory_management.dart';

// Customer pages
import 'package:yang_chow/pages/customer/customer_dashboard.dart';
import 'package:yang_chow/pages/customer/payment_page.dart';

// Root/shared auth pages
import 'package:yang_chow/pages/login_page.dart';
import 'package:yang_chow/pages/forgot_password_page.dart';
```

## Page Descriptions

### Admin Folder (8 files)

#### admin_announcements_page.dart
- **Purpose**: Announcements management and display
- **Features**: Add/edit/delete announcements, auto-expiration based on event schedule
- **Dependencies**: Supabase (announcements table)

#### admin_dashboard.dart
- **Purpose**: Real-time admin analytics dashboard
- **Features**: 
  - Real-time order/inventory/reservation streams
  - KPI cards with live metrics
  - Event analytics and conflict detection
  - Countdown timers for active events
- **Dependencies**: fl_chart, Supabase (multiple real-time streams)
- **Size**: ~2500+ lines (complex multi-stream implementation)

#### admin_chat_page.dart
- **Purpose**: Admin-to-customer messaging interface
- **Features**: Thread-based chat with unread notifications
- **Dependencies**: Supabase (chat tables), real_time subscriptions

#### admin_main_page.dart
- **Purpose**: Admin navigation hub and page routing
- **Features**: Sidebar/drawer navigation to all admin pages
- **Imports**: user_management, sales_report, inventory_management (from staff/), admin_dashboard, admin_reservations, admin_announcements, admin_chat

#### admin_reservations_page.dart
- **Purpose**: Event and reservation management
- **Features**: Create/edit/delete reservations, conflict detection, status management
- **Dependencies**: Supabase (reservations table)

#### user_management.dart
- **Purpose**: Staff/admin organization chart and management
- **Features**: View user hierarchy, manage permissions
- **Dependencies**: Supabase (users table with role hierarchy)

#### sales_report_page.dart
- **Purpose**: Analytics and sales reporting
- **Features**: 
  - Transaction history with filtering
  - Monthly/yearly summaries
  - CSV export functionality
- **Dependencies**: Supabase (orders, transactions), csv package
- **Size**: ~1800+ lines

#### pagsanjaninv_dashboard.dart
- **Purpose**: Inventory management dashboard (Pagsanjaninv)
- **Features**: Real-time stock tracking, room inventory, forecasting
- **Imports**: inventory_management, inventory_forecast_page, inventory_room_page (from staff/)
- **Dependencies**: Supabase (inventory tables)

---

### Staff Folder (7 files)

#### staff_login_page.dart
- **Purpose**: Staff authentication entry point
- **Features**: 
  - Email/password login for staff
  - Role validation
  - Gradient background design (reference style for login pages)
- **Dependencies**: Supabase Auth

#### staff_dashboard.dart
- **Purpose**: Main staff operations hub
- **Features**: Order management, kitchen display, inventory quick access
- **Imports**: staff_order_history_page
- **Dependencies**: Supabase real-time streams

#### chef_dashboard.dart
- **Purpose**: Kitchen operations interface
- **Features**: Active orders view, preparation status tracking, order timing
- **Dependencies**: Supabase (orders with details)

#### staff_order_history_page.dart
- **Purpose**: Historical order viewing and filtering
- **Features**: Order search, status history, preparation details
- **Dependencies**: Supabase (orders archive)

#### inventory_management.dart
- **Purpose**: Core inventory management interface
- **Features**: Stock tracking, item management, threshold alerts
- **Dependencies**: Supabase (inventory tables)

#### inventory_room_page.dart
- **Purpose**: Individual storage room inventory
- **Features**: Room-specific stock display, item movement
- **Dependencies**: Supabase (room_inventory tables)

#### inventory_forecast_page.dart
- **Purpose**: Inventory forecasting and predictions
- **Features**: Stock trend analysis, consumption predictions
- **Dependencies**: Supabase (historical inventory data)

---

### Customer Folder (6 files)

#### customer_chat_page.dart
- **Purpose**: Customer support/chat messaging
- **Features**: Real-time messaging with admin, notification badges
- **Dependencies**: Supabase (chat tables), real_time subscriptions

#### customer_dashboard.dart
- **Purpose**: Main customer dashboard
- **Features**: 
  - Reservation management
  - Payment history
  - Profile management
  - Chat access
- **Imports**: payment_page, edit_profile_page, customer_chat_page
- **Dependencies**: Supabase (multiple customer tables)

#### customer_registration_page.dart
- **Purpose**: New customer signup
- **Features**: 
  - Email/password registration
  - Terms & Conditions modal acceptance
  - Remember Me checkbox persistence
  - Form validation
- **Dependencies**: Supabase Auth, SharedPreferences

#### customer_reviews_page.dart
- **Purpose**: Customer review and rating submission
- **Features**: Star ratings, written reviews, submission to orders
- **Dependencies**: Supabase (reviews table)

#### edit_profile_page.dart
- **Purpose**: Customer profile management
- **Features**: Update name, phone, address, avatar
- **Dependencies**: Supabase (users table)

#### payment_page.dart
- **Purpose**: Payment processing and history
- **Features**: 
  - PayMongo integration
  - Order payment status
  - Payment method management
  - Invoice generation
- **Dependencies**: PayMongo API, Supabase (orders, payments)

---

### Shared Auth Pages (4 files in lib/pages/ root)

#### login_page.dart
- **Purpose**: Customer login page
- **Features**: 
  - Email/password authentication
  - Google Sign-In integration
  - Remember Me functionality (SharedPreferences)
  - Mobile responsive layout with customer icon/title card
- **Dependencies**: Supabase Auth, SharedPreferences, google_sign_in

#### forgot_password_page.dart
- **Purpose**: Password recovery flow
- **Features**: 
  - Email-based password reset
  - Remember email option (SharedPreferences)
- **Dependencies**: Supabase Auth, SharedPreferences

#### landing_page.dart
- **Purpose**: Initial app landing/onboarding
- **Features**: App introduction, navigation to registration/login
- **Dependencies**: None (navigation only)

#### update_password_page.dart
- **Purpose**: Change password for authenticated users
- **Features**: Current password validation, new password strength checking
- **Dependencies**: Supabase Auth

---

## Cross-Folder Dependencies

Some files reference pages from other folders:

```dart
// admin_main_page imports from multiple folders
import 'package:yang_chow/pages/admin/admin_dashboard.dart';
import 'package:yang_chow/pages/admin/user_management.dart';
import 'package:yang_chow/pages/staff/inventory_management.dart';

// pagsanjaninv_dashboard imports staff inventory pages
import 'package:yang_chow/pages/staff/inventory_management.dart';
import 'package:yang_chow/pages/staff/inventory_forecast_page.dart';
import 'package:yang_chow/pages/staff/inventory_room_page.dart';

// customer_dashboard imports customer pages
import 'package:yang_chow/pages/customer/payment_page.dart';
import 'package:yang_chow/pages/customer/edit_profile_page.dart';
import 'package:yang_chow/pages/customer/customer_chat_page.dart';
```

All cross-folder imports are properly qualified with full package paths to avoid conflicts.

---

## Key Features by Domain

### Authentication & Security
- **Multi-role support**: Customer, Staff, Chef, Admin
- **OAuth Integration**: Google Sign-In for customers
- **Remember Me**: SharedPreferences persistence for login credentials
- **Password Recovery**: Email-based reset flow
- **Terms & Conditions**: Modal acceptance on customer registration

### Real-Time Capabilities
- **Live Streams**: Order, inventory, reservation streams via Supabase
- **Chat System**: Real-time messaging with unread badges
- **Activity Updates**: Live dashboard updates for admin/staff

### Payment Processing
- **PayMongo Integration**: Credit card payments
- **Invoice Generation**: Automated billing
- **Payment History**: Transaction tracking

### Inventory Management
- **Stock Tracking**: Real-time inventory by room/location
- **Forecasting**: Consumption-based predictions
- **Threshold Alerts**: Low-stock notifications

---

## Important Notes

1. **Root Auth Pages**: login_page, forgot_password_page, landing_page, and update_password_page remain in `lib/pages/` root (not in subfolders) for backward compatibility with main.dart routing.

2. **Import Updates**: When adding new files or moving files, ensure all imports are updated to use the correct subfolder path.

3. **Shared Services**: All service files (authentication, database, API) remain in `lib/services/` at the root level. Pages import from there directly.

4. **Build Status**: Project compiles with zero errors after reorganization. All imports have been verified.

5. **Adding New Pages**: 
   - Admin pages: Create in `lib/pages/admin/` and import as `package:yang_chow/pages/admin/filename.dart`
   - Staff pages: Create in `lib/pages/staff/` and import as `package:yang_chow/pages/staff/filename.dart`
   - Customer pages: Create in `lib/pages/customer/` and import as `package:yang_chow/pages/customer/filename.dart`

---

## Statistics

- **Total Page Files**: 25
- **Admin Pages**: 8
- **Staff Pages**: 7
- **Customer Pages**: 6
- **Shared Auth Pages**: 4
- **Total Lines of Code**: ~15,000+ (main page files)
- **Build Status**: ✅ Compiles cleanly (zero new errors, 3 pre-existing info warnings)
