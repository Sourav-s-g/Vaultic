# Feature Analysis: Smart Input Layer & Context-Aware Defaulting

## 📋 Overview
This document outlines all changes needed to implement:
1. **Smart Input Layer** - Quick add bar with NLP parsing
2. **Context-Aware Defaulting** - Intelligent pre-filling based on history

---

## 🎯 Feature 1: Smart Input Layer (Predictive + Minimal Taps)

### 1.1 New Files to Create

#### `lib/services/smart_input_parser.dart` (NEW)
**Purpose:** Parse natural language input into structured transaction data

**Key Components:**
- `parseInput(String input)` → Returns `ParsedTransaction` object
- `extractAmount(String input)` → Extracts numeric amount (₹500, 250, etc.)
- `detectCategory(String input, List<String> categories)` → Matches keywords to categories
- `detectType(String input)` → Detects Credit/Debit from keywords
- `extractDescription(String input)` → Extracts clean description

**Keyword Mapping:**
```dart
// Category keywords (configurable)
Map<String, List<String>> categoryKeywords = {
  'Food': ['lunch', 'dinner', 'breakfast', 'food', 'restaurant', 'cafe'],
  'Transport': ['fuel', 'petrol', 'uber', 'taxi', 'metro', 'bus'],
  'Shopping': ['buy', 'purchase', 'shopping', 'mall'],
  'Income': ['salary', 'wage', 'income', 'payment', 'received'],
  // ... more mappings
};
```

**Type Detection:**
- Credit keywords: "salary", "received", "income", "got", "paid me"
- Debit keywords: "spent", "paid", "bought", "expense"

#### `lib/models/parsed_transaction.dart` (NEW)
**Purpose:** Data model for parsed transaction data

**Fields:**
- `double? amount`
- `String? category`
- `String? type` (Credit/Debit)
- `String description`
- `DateTime? date` (defaults to today)
- `double confidence` (0.0-1.0) - parsing confidence score
- `Map<String, dynamic> rawInput` - original input for review

#### `lib/widgets/quick_add_bar.dart` (NEW)
**Purpose:** Single-line input bar for quick transaction entry

**UI Components:**
- Text field with hint: "Type: Lunch 250 or Got ₹500 salary"
- Auto-complete suggestions as user types
- "Expand" button to open full dialog
- Submit button (checkmark icon)
- Real-time parsing feedback (shows detected category/amount)

---

### 1.2 Files to Modify

#### `lib/HomePage.dart`
**Changes Needed:**

1. **Add Quick Add Bar Widget**
   - Place at top of dashboard (after app bar, before balance card)
   - Import `quick_add_bar.dart`
   - State management for quick add input

2. **Modify `_showAddTransactionDialog()`**
   - Accept optional `ParsedTransaction?` parameter
   - Pre-fill form fields from parsed data
   - Show "parsed from: [input]" indicator
   - Allow user to edit any pre-filled values

3. **Add Quick Add Handler**
   ```dart
   Future<void> _handleQuickAdd(String input) async {
     final parsed = SmartInputParser.parseInput(input);
     if (parsed.confidence > 0.7) {
       // Auto-submit if high confidence
       await _saveQuickTransaction(parsed);
     } else {
       // Open expanded dialog for review
       await _showAddTransactionDialog(parsedTransaction: parsed);
     }
   }
   ```

4. **Add Quick Transaction Save**
   - Similar to `addTransaction` but with pre-filled data
   - Validate before saving
   - Show success/error feedback

#### `lib/services/hybrid_storage_service.dart`
**Changes Needed:**

1. **Add Category Keyword Mapping Storage**
   - New key: `_categoryKeywordsKey = 'vaultic_category_keywords_v1'`
   - Methods:
     - `getCategoryKeywords()` → Returns `Map<String, List<String>>`
     - `saveCategoryKeywords(Map<String, List<String>> keywords)`
     - `getKeywordsForCategory(String category)` → Returns keywords for a category
   - Learn from user input: auto-add keywords when category is manually selected

2. **Add Last Used Category Tracking**
   - New key: `_lastCategoryPerKeywordKey = 'vaultic_last_category_keywords_v1'`
   - Store: `{keyword: category}` mapping based on user selections
   - Methods:
     - `getLastCategoryForKeyword(String keyword)` → Returns most recently used category
     - `updateCategoryForKeyword(String keyword, String category)` → Update mapping

---

### 1.3 Database Schema Changes (Supabase)

#### New Table: `category_keywords` (Optional - for cloud sync)
```sql
CREATE TABLE category_keywords (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  category_name TEXT NOT NULL,
  keywords TEXT[] NOT NULL, -- Array of keywords
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

---

## 🎯 Feature 2: Context-Aware Defaulting

### 2.1 New Files to Create

#### `lib/services/context_aware_service.dart` (NEW)
**Purpose:** Manage context-aware defaults and pattern detection

**Key Components:**

1. **Last Used Category Tracking**
   - `getLastCategoryForDescription(String description)` → Analyze description, find similar past transactions
   - `getLastCategoryForKeyword(String keyword)` → Get category from keyword history
   - `updateCategoryMapping(String description, String category)` → Learn from user selection

2. **Auto Type Detection**
   - `detectTypeFromCategory(String category)` → Rules: "Salary" → Credit, "Food" → Debit
   - `detectTypeFromDescription(String description)` → NLP-based detection
   - `getDefaultType()` → Returns most common type (likely Debit)

3. **Recurring Transaction Detection**
   - `detectRecurringPattern(Transaction transaction)` → Check if similar transaction exists monthly
   - `isRecurringTransaction(Transaction transaction)` → Boolean check
   - `getRecurringSuggestions()` → List of transactions that appear monthly

4. **Pattern Analysis**
   - `analyzeTransactionPatterns()` → Find monthly/weekly patterns
   - `getSuggestedRecurring()` → Suggest transactions to mark as recurring

#### `lib/models/recurring_transaction.dart` (NEW)
**Purpose:** Model for recurring transactions

**Fields:**
- `String id`
- `String description`
- `double amount`
- `String type`
- `String category`
- `String frequency` (daily, weekly, monthly, yearly)
- `DateTime startDate`
- `DateTime? endDate`
- `bool isActive`
- `int? dayOfMonth` (for monthly)
- `String? dayOfWeek` (for weekly)

#### `lib/services/recurring_transaction_service.dart` (NEW)
**Purpose:** Manage recurring transactions

**Key Methods:**
- `addRecurringTransaction(RecurringTransaction recurring)`
- `getAllRecurringTransactions()`
- `markAsRecurring(String transactionId, String frequency)`
- `processRecurringTransactions()` → Auto-create transactions for due dates
- `suggestRecurringFromHistory()` → Analyze history and suggest recurring patterns

---

### 2.2 Files to Modify

#### `lib/services/hybrid_storage_service.dart`
**Changes Needed:**

1. **Add Last Used Category Storage**
   - New keys:
     - `_lastCategoryPerDescriptionKey = 'vaultic_last_category_desc_v1'`
     - `_lastCategoryPerKeywordKey = 'vaultic_last_category_keyword_v1'`
   - Methods:
     ```dart
     Future<String?> getLastCategoryForDescription(String description)
     Future<void> updateCategoryForDescription(String description, String category)
     Future<Map<String, String>> getAllCategoryMappings()
     ```

2. **Add Recurring Transaction Storage**
   - New key: `_recurringTransactionsKey = 'vaultic_recurring_txns_v1'`
   - Methods:
     ```dart
     Future<List<Map<String, dynamic>>> getRecurringTransactions()
     Future<void> saveRecurringTransactions(List<Map<String, dynamic>> recurring)
     Future<void> addRecurringTransaction(Map<String, dynamic> recurring)
     ```

3. **Add Pattern Learning**
   - Store transaction patterns: `_transactionPatternsKey = 'vaultic_txn_patterns_v1'`
   - Analyze frequency, amounts, categories
   - Learn user habits over time

#### `lib/HomePage.dart`
**Changes Needed:**

1. **Modify `_showAddTransactionDialog()`**
   - **Pre-fill Category:**
     ```dart
     // Before showing dialog
     String? suggestedCategory;
     if (descriptionController.text.isNotEmpty) {
       suggestedCategory = await ContextAwareService
         .getLastCategoryForDescription(descriptionController.text);
     }
     // Use suggestedCategory as default value
     ```

   - **Auto-detect Type:**
     ```dart
     String suggestedType = await ContextAwareService
       .detectTypeFromCategory(category) ?? 'Debit';
     // Pre-select in dropdown
     ```

   - **Show Recurring Suggestion:**
     ```dart
     // After transaction is saved
     bool isRecurring = await RecurringTransactionService
       .detectRecurringPattern(transaction);
     if (isRecurring) {
       // Show dialog: "This looks like a recurring transaction. Mark as recurring?"
     }
     ```

2. **Add Recurring Transaction UI**
   - Add "Recurring Transactions" section in dashboard
   - Show upcoming recurring transactions
   - Add badge/indicator for recurring transactions in list

3. **Add Context-Aware Suggestions**
   - Show category suggestions as user types description
   - Auto-complete dropdown for categories
   - Highlight most likely category

#### `lib/screens/settings_screen.dart`
**Changes Needed:**

1. **Add Recurring Transactions Management**
   - New tile: "Manage Recurring Transactions"
   - Navigate to new screen: `RecurringTransactionsScreen`

2. **Add Smart Input Settings**
   - Toggle: "Enable Smart Input Parsing"
   - Toggle: "Enable Context-Aware Suggestions"
   - Button: "Reset Learned Patterns"

#### `lib/screens/recurring_transactions_screen.dart` (NEW)
**Purpose:** Manage recurring transactions

**Features:**
- List all recurring transactions
- Add new recurring transaction
- Edit/delete recurring transactions
- View upcoming transactions
- Toggle active/inactive

---

### 2.3 Database Schema Changes (Supabase)

#### New Table: `recurring_transactions`
```sql
CREATE TABLE recurring_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  description TEXT NOT NULL,
  amount DECIMAL NOT NULL,
  type TEXT NOT NULL, -- 'Credit' or 'Debit'
  category TEXT,
  frequency TEXT NOT NULL, -- 'daily', 'weekly', 'monthly', 'yearly'
  start_date DATE NOT NULL,
  end_date DATE,
  is_active BOOLEAN DEFAULT true,
  day_of_month INTEGER,
  day_of_week TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

#### New Table: `category_patterns` (Optional - for learning)
```sql
CREATE TABLE category_patterns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  keyword TEXT NOT NULL,
  category TEXT NOT NULL,
  usage_count INTEGER DEFAULT 1,
  last_used TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 🔄 Integration Points

### Where Changes Connect:

1. **Smart Input → Context-Aware:**
   - Quick add bar uses `ContextAwareService` for category suggestions
   - Parsed transactions learn from user corrections

2. **Context-Aware → Transaction Dialog:**
   - Full dialog pre-fills using `ContextAwareService`
   - Both quick add and full dialog use same learning system

3. **Recurring → Transaction History:**
   - Recurring transactions appear in history with special badge
   - Auto-generated transactions marked with `isRecurring: true`

4. **Learning Loop:**
   ```
   User Input → Parse → Save → Learn Pattern → Improve Next Suggestion
   ```

---

## 📊 Data Flow

### Smart Input Flow:
```
User types "Lunch 250"
    ↓
SmartInputParser.parseInput()
    ↓
Extracts: amount=250, description="Lunch"
    ↓
ContextAwareService.getLastCategoryForKeyword("lunch")
    ↓
Returns: "Food" (from past history)
    ↓
Detects type: "Debit" (from category)
    ↓
Pre-fills: amount=250, category="Food", type="Debit", date=today
    ↓
User confirms → Save → Learn pattern
```

### Context-Aware Defaulting Flow:
```
User opens transaction dialog
    ↓
User types description: "Fuel"
    ↓
ContextAwareService.getLastCategoryForKeyword("fuel")
    ↓
Returns: "Transport" (from last "Fuel" transaction)
    ↓
Auto-selects category: "Transport"
    ↓
Auto-detects type: "Debit" (Transport = expense)
    ↓
User confirms → Save → Update keyword mapping
```

### Recurring Detection Flow:
```
User saves transaction: "Netflix 999" on Jan 15
    ↓
RecurringTransactionService.detectRecurringPattern()
    ↓
Checks: Similar transaction exists in Dec, Nov, Oct?
    ↓
If found → Shows dialog: "Mark as Monthly Recurring?"
    ↓
User confirms → Creates RecurringTransaction
    ↓
Next month → Auto-creates transaction on 15th
```

---

## 🎨 UI/UX Changes

### HomePage UI:
1. **Quick Add Bar** (new)
   - Position: Top of dashboard, below app bar
   - Styling: Rounded, prominent, with icon
   - Auto-complete dropdown below

2. **Transaction Dialog** (enhanced)
   - Pre-filled fields highlighted (subtle background)
   - "Suggested" badges on auto-filled values
   - "Recurring?" checkbox/toggle
   - "Learn from this" toggle (default: on)

3. **Recurring Transactions Section** (new)
   - Card showing upcoming recurring transactions
   - Badge count: "3 recurring this month"
   - Tap to view/manage

### Settings Screen:
1. **Smart Input Settings** (new section)
   - Toggle: "Enable Smart Parsing"
   - Toggle: "Enable Auto-suggestions"
   - Button: "Reset Learned Patterns"

2. **Recurring Transactions** (new tile)
   - Navigate to management screen

---

## 🔧 Technical Considerations

### Performance:
- **Keyword Matching:** Use efficient string matching (fuzzy matching optional)
- **Pattern Detection:** Cache patterns, analyze on background thread
- **Auto-complete:** Debounce input (300ms) before showing suggestions

### Privacy:
- All learning happens locally (optional cloud sync)
- User can reset patterns anytime
- No external NLP services (local parsing only)

### Offline Support:
- All parsing works offline
- Context-aware defaults work offline
- Recurring detection works offline

### Sync Considerations:
- Category keywords sync to Supabase (optional)
- Recurring transactions sync to Supabase
- Pattern learning can be local-only (privacy)

---

## 📝 Implementation Priority

### Phase 1: Core Smart Input (Week 1)
1. Create `SmartInputParser` service
2. Create `ParsedTransaction` model
3. Add quick add bar to HomePage
4. Basic keyword → category mapping

### Phase 2: Context-Aware Defaulting (Week 2)
1. Create `ContextAwareService`
2. Implement last-used category tracking
3. Auto type detection
4. Pre-fill in transaction dialog

### Phase 3: Recurring Transactions (Week 3)
1. Create `RecurringTransaction` model
2. Create `RecurringTransactionService`
3. Pattern detection algorithm
4. UI for managing recurring transactions

### Phase 4: Advanced Features (Week 4)
1. NLP parsing improvements
2. Fuzzy matching for categories
3. Pattern learning refinement
4. Analytics/insights

---

## 🧪 Testing Checklist

### Smart Input:
- [ ] Parse "Lunch 250" → category=Food, amount=250
- [ ] Parse "Got ₹500 salary" → type=Credit, amount=500
- [ ] Handle invalid input gracefully
- [ ] Auto-complete shows correct suggestions
- [ ] Expand button opens full dialog with pre-filled data

### Context-Aware:
- [ ] Last used category appears as default
- [ ] Type auto-detects from category
- [ ] Patterns learn from user corrections
- [ ] Reset patterns works correctly

### Recurring:
- [ ] Detects monthly patterns correctly
- [ ] Suggests recurring when pattern found
- [ ] Auto-creates transactions on due dates
- [ ] Manages recurring transactions correctly

---

## 📚 Additional Notes

### Keyword Mapping Strategy:
- Start with predefined mappings (Food, Transport, etc.)
- Learn from user selections
- Store most common mappings per user
- Allow manual keyword management in settings

### Confidence Scoring:
- High confidence (>0.7): Auto-submit
- Medium confidence (0.4-0.7): Show in dialog for review
- Low confidence (<0.4): Open full dialog

### Fallback Behavior:
- If parsing fails → Open full dialog
- If category not found → Use "General" or prompt user
- If amount not found → Prompt user

---

## 🚀 Future Enhancements (Post-MVP)

1. **Voice Input:** "Add lunch 250 rupees"
2. **Image Recognition:** Scan receipts → auto-extract data
3. **ML Model:** Train on user's transaction history
4. **Smart Categories:** Auto-create categories from patterns
5. **Budget Suggestions:** Based on recurring patterns

---

**End of Analysis**

