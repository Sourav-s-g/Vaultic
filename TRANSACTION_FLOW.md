# Transaction Addition Flow

## Complete Flow Diagram

```
User Action (HomePage)
    ↓
_showAddTransactionDialog()
    ↓
User fills form → Clicks "Save"
    ↓
Creates transaction map
    ↓
HybridStorageService.addTransaction()
    ↓
┌─────────────────────────────────────┐
│ 1. CREATE BACKUP (Safety)            │
│    - Get current transactions        │
│    - Create backup copy              │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 2. ADD TO LOCAL STORAGE              │
│    - Add transaction to list        │
│    - Save to SharedPreferences      │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 3. SYNC TO CLOUD (if authenticated) │
│    - SupabaseService.addTransaction()│
│    - If fails: Log error but continue│
│      (Local data is already saved)  │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 4. MONTHLY ROLLOVER CHECK           │
│    (Only if NOT carry-forward txn)  │
│    ↓                                │
│    _checkAndProcessMonthlyRollover()│
│    ↓                                │
│    For each unprocessed month:       │
│    ├─ Calculate month-end balance   │
│    ├─ If positive: Add carry-forward│
│    │   credit to next month         │
│    └─ If negative: Add OWO entry    │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 5. ERROR HANDLING (if any step fails)│
│    - Restore from backup            │
│    - Re-throw error                  │
└─────────────────────────────────────┘
    ↓
Back to UI → _loadAllTransactions()
    ↓
UI Updates with new transaction
```

## Step-by-Step Breakdown

### Step 1: User Interaction (HomePage.dart)

**Location:** `lib/HomePage.dart` - `_showAddTransactionDialog()`

1. User clicks the "+" FloatingActionButton
2. Dialog opens with form fields:
   - Amount
   - Description
   - Date (default: today)
   - Type (Credit/Debit)
   - Category (if Debit)
3. User fills form and clicks "Save"
4. Transaction map is created:
   ```dart
   {
     'transactionId': UUID,
     'description': string,
     'amount': double,
     'type': 'Credit' or 'Debit',
     'date': ISO8601 string,
     'category': string,
     'status': 'Completed',
     'isSplit': false,
     'splitCount': 1
   }
   ```

### Step 2: Add Transaction Method (HybridStorageService)

**Location:** `lib/services/hybrid_storage_service.dart` - `addTransaction()`

#### 2.1 Create Safety Backup
```dart
final transactions = await getTransactions();
final backup = List<Map<String, dynamic>>.from(transactions);
```
- Creates a backup copy of current transactions
- Used for rollback if save fails

#### 2.2 Add to Local Storage
```dart
transactions.add(transaction);
await _saveToLocal(_transactionsKey, transactions);
```
- Adds transaction to the list
- Saves to SharedPreferences immediately
- **UI sees the change right away**

#### 2.3 Sync to Cloud (if authenticated)
```dart
if (_isAuthenticated) {
  await SupabaseService.addTransaction(transaction);
}
```
- Attempts to save to Supabase
- If cloud save fails, local data is still saved
- User doesn't lose data even if cloud is down

#### 2.4 Monthly Rollover Check
```dart
if (!isCarryForward) {
  await _checkAndProcessMonthlyRollover();
}
```
- Only runs if transaction is NOT a carry-forward transaction
- Prevents infinite recursion

### Step 3: Monthly Rollover Process

**Location:** `lib/services/hybrid_storage_service.dart` - `_checkAndProcessMonthlyRollover()`

#### 3.1 Find Unprocessed Months
- Gets list of processed months from storage
- Finds earliest transaction date
- Iterates through all completed months (not current month)

#### 3.2 For Each Unprocessed Month:

**Calculate Month-End Balance:**
```dart
final monthEndBalance = calculateMonthEndBalance(year, month);
// Formula: Initial Balance + Credits - Debits
```

**If Positive Balance:**
- Creates carry-forward credit transaction
- Date: 1st of next month
- Description: "Balance carried forward from [Month Year]"
- Amount: Positive balance amount
- Marked with `isCarryForward: true`

**If Negative Balance:**
- Creates OWO entry
- Counterparty: "[Month Year] Balance"
- Direction: "owe"
- Amount: Absolute value of negative balance
- Note: "Negative balance from [Month Year]"

#### 3.3 Mark Month as Processed
- Adds month key to processed months list
- Prevents duplicate processing

### Step 4: Error Handling

If any step fails:
```dart
try {
  // Save transaction
} catch (e) {
  // Restore from backup
  await _saveToLocal(_transactionsKey, backup);
  rethrow; // Re-throw error to UI
}
```

### Step 5: UI Update

**Location:** `lib/HomePage.dart`
```dart
await HybridStorageService.addTransaction(txnMap);
_loadAllTransactions(); // Refresh UI
```

## Important Notes

### 1. **Local-First Strategy**
- Always saves locally first
- Cloud sync is secondary
- User never loses data if cloud fails

### 2. **Recursion Prevention**
- Carry-forward transactions have `isCarryForward: true`
- Monthly rollover check skips these transactions
- Prevents infinite loops

### 3. **Monthly Rollover Logic**
- Only processes completed months (not current month)
- Each month is processed only once
- Tracks processed months to avoid duplicates

### 4. **Data Integrity**
- Backup created before any changes
- Rollback on failure
- Cloud sync doesn't block local save

## Example Flow

**Scenario:** User adds a ₹1000 Debit transaction on January 15, 2024

1. ✅ Transaction saved locally
2. ✅ Transaction synced to cloud (if authenticated)
3. ✅ Monthly rollover check runs
4. ✅ December 2023 (if completed):
   - Calculates balance
   - If positive: Creates January 1st credit
   - If negative: Creates OWO entry
5. ✅ UI refreshes showing new transaction

## Timeline

```
T0: User clicks Save
T1: Backup created (< 1ms)
T2: Local save complete (< 5ms)
T3: Cloud sync started (async, non-blocking)
T4: Monthly rollover check (if needed, < 100ms)
T5: UI updates (< 10ms)
Total: ~100-200ms (user perceives as instant)
```

