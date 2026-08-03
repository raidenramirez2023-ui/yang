# Petty Cash System Setup Guide

## Overview
The Petty Cash System allows staff to record inventory purchase expenses when they use their own money to buy items for the restaurant. The system tracks:
- Petty cash fund balance
- Individual expenses with proof of purchase
- Approval workflow for expenses
- Reimbursement tracking

## Features
- **Admin View**: Manage petty cash fund, approve/reject expenses, view all expenses
- **Staff View**: Record expenses, view own expenses, edit pending expenses
- **Real-time Updates**: Live balance and expense tracking
- **Inventory Integration**: Link expenses to specific inventory items

## Setup Instructions

### 1. Run SQL Migration
Execute the SQL script in your Supabase SQL Editor:

```bash
# Run the SQL file
database/sql/create_petty_cash.sql
```

This will create:
- `petty_cash_fund` table - tracks the main fund balance
- `petty_cash_expenses` table - tracks individual expenses
- Row Level Security (RLS) policies
- Indexes for performance

### 2. Initialize Petty Cash Fund
After running the SQL script, an admin needs to initialize the petty cash fund:

1. Log in as admin
2. Navigate to **Petty Cash** in the admin panel
3. Click the **Initialize Fund** button
4. Enter the initial amount (e.g., ₱5,000)
5. Click **Initialize**

### 3. Staff Usage
Staff can now record expenses:

1. Log in as staff
2. Click the **Petty Cash Expenses** icon (receipt icon) in the staff dashboard
3. Click the **+** button to add a new expense
4. Fill in the expense details:
   - **Category**: Select expense type (Inventory Purchase, Supplies, Transportation, Other)
   - **Inventory Item**: If purchasing inventory, select the item from the dropdown
   - **Description**: Describe what was purchased
   - **Amount**: Enter the amount spent
   - **Supplier**: (Optional) Name of the supplier
   - **Receipt Number**: (Optional) Receipt/reference number
   - **Notes**: (Optional) Additional details
5. Click **Save**

### 4. Admin Approval Workflow
Admins review and approve expenses:

1. Navigate to **Petty Cash** in admin panel
2. View the fund balance and expense statistics
3. Filter expenses by status or category
4. For pending expenses:
   - Click **Approve** to approve the expense
   - Click **Reject** to reject and refund the amount to the fund
5. Approved expenses can be marked as **Reimbursed** once staff is paid back

### 5. Fund Management
Admins can manage the petty cash fund:

- **Replenish Fund**: Add more money to the fund
- **View Statistics**: See total expenses, pending amounts, reimbursed amounts
- **Track History**: View all expense history with filters

## Expense Status Flow
1. **Pending** - Expense submitted by staff, awaiting admin review
2. **Approved** - Expense approved by admin, awaiting reimbursement
3. **Rejected** - Expense rejected, amount refunded to fund
4. **Reimbursed** - Staff has been reimbursed for the expense

## Security Features
- Row Level Security (RLS) ensures users can only see their own expenses
- Only admins can approve/reject expenses
- Only admins can manage the petty cash fund
- Automatic balance validation before creating expenses

## Navigation
- **Admin**: Admin Panel → Petty Cash
- **Staff**: Staff Dashboard → Receipt Icon (Petty Cash Expenses)

## Troubleshooting

### Fund not initialized
If staff see "Petty Cash Fund Not Available":
- Admin needs to initialize the fund first
- Navigate to Petty Cash page and click "Initialize Fund"

### Insufficient balance
If expense creation fails with "Insufficient petty cash balance":
- Admin needs to replenish the fund
- Check current balance before recording expenses

### Permission errors
If users can't access petty cash features:
- Check RLS policies are properly applied
- Verify user roles in the users table
- Ensure SQL migration was run successfully

## Database Schema

### petty_cash_fund
- `id` - UUID primary key
- `fund_name` - Fund identifier (default: "Main Petty Cash")
- `current_balance` - Current available balance
- `initial_balance` - Initial fund amount
- `last_replenished_at` - Last replenishment timestamp
- `created_at` - Creation timestamp
- `updated_at` - Last update timestamp

### petty_cash_expenses
- `id` - UUID primary key
- `expense_date` - Date of expense
- `description` - Expense description
- `amount` - Amount spent
- `category` - Expense category
- `purchased_by` - Email of staff who made purchase
- `inventory_item_id` - Link to inventory item (if applicable)
- `inventory_item_name` - Name of inventory item
- `quantity_purchased` - Quantity purchased
- `supplier` - Supplier name
- `receipt_image_url` - URL to receipt image (future feature)
- `receipt_number` - Receipt/reference number
- `status` - Expense status (pending, approved, rejected, reimbursed)
- `approved_by` - Email of admin who approved
- `approved_at` - Approval timestamp
- `notes` - Additional notes
- `created_at` - Creation timestamp
- `updated_at` - Last update timestamp

## Future Enhancements
- Receipt image upload
- Export expense reports to PDF/CSV
- Expense categories customization
- Budget limits per category
- Multi-fund support
