import 'dart:math';
import '../models/parsed_transaction.dart';

class SmartInputParser {
  // Predefined keyword mappings for categories
  static final Map<String, List<String>> categoryKeywords = {
  'Food': [
    'lunch', 'dinner', 'breakfast', 'food', 'restaurant', 'cafe', 'meal', 'eat',
    'pizza', 'burger', 'coffee', 'tea', 'snacks', 'grocery', 'biryani', 'juice',
    'bakery', 'ice cream', 'canteen', 'kitchen', 'veg', 'non-veg', 'swiggy', 'zomato'
  ],

  'Transport': [
    'fuel', 'petrol', 'diesel', 'uber', 'taxi', 'metro', 'bus', 'train', 'flight',
    'cab', 'auto', 'rickshaw', 'parking', 'toll', 'fare', 'ticket', 'ola',
    'airfare', 'commute', 'subway', 'carwash', 'driver', 'transport', 'travel'
  ],

  'Shopping': [
    'buy', 'purchase', 'shopping', 'mall', 'store', 'market', 'amazon', 'flipkart',
    'bigbasket', 'myntra', 'ajio', 'grocery', 'fashion', 'clothes', 'footwear',
    'electronics', 'appliance', 'supermarket', 'accessory', 'home decor', 'gadget',
    'boutique', 'jewelry'
  ],

  'Income': [
    'salary', 'wage', 'income', 'payment', 'received', 'got', 'paid me', 'earned',
    'bonus', 'commission', 'interest', 'refund', 'dividend', 'cashback',
    'freelance', 'stipend', 'reimbursement', 'transfer in', 'deposit', 'inflow'
  ],

  'Entertainment': [
    'movie', 'cinema', 'netflix', 'spotify', 'game', 'concert', 'show', 'theatre',
    'event', 'music', 'ticket', 'fun', 'outing', 'amusement', 'party', 'club',
    'youtube', 'subscription', 'hotstar', 'zee5', 'bookmyshow'
  ],

  'Bills': [
    'bill', 'electricity', 'water', 'internet', 'phone', 'mobile', 'rent', 'gas',
    'postpaid', 'prepaid', 'wifi', 'broadband', 'tv', 'dth', 'insurance', 'loan emi',
    'credit card', 'maintenance', 'subscription', 'charge', 'payment due'
  ],

  'Health': [
    'hospital', 'doctor', 'medicine', 'pharmacy', 'clinic', 'medical', 'health',
    'checkup', 'test', 'scan', 'diagnostic', 'surgery', 'dentist', 'eye care',
    'therapy', 'insurance', 'covid', 'vaccine', 'fitness', 'gym', 'protein', 'consultation'
  ],

  'Education': [
    'school', 'college', 'tuition', 'course', 'book', 'study', 'exam', 'fees',
    'class', 'university', 'training', 'online course', 'udemy', 'coursera',
    'byjus', 'notebook', 'stationery', 'learning', 'coaching', 'degree', 'certificate'
  ],

  'General': [
    'misc', 'other', 'unknown', 'general', 'personal', 'expense', 'transfer',
    'miscellaneous', 'temp', 'adjustment', 'undefined', 'others', 'service', 'fee',
    'charge', 'transaction'
  ],
};


  // Credit keywords (positive money flow)
  static final List<String> creditKeywords = [
    'salary', 'wage', 'income', 'received', 'receive', 'receiving', 'credited', 'credit', 'cr', 'got', 'paid me', 'earned', 'refund', 'bonus'
  ];

  // Debit keywords (negative money flow)
  static final List<String> debitKeywords = [
    'spent', 'paid', 'bought', 'purchase', 'expense', 'cost', 'bill'
  ];

  /// Parse natural language input into structured transaction data
  static ParsedTransaction parseInput(String input, List<String> availableCategories) {
    if (input.trim().isEmpty) {
      return ParsedTransaction(
        description: '',
        rawInput: input,
        confidence: 0.0,
      );
    }

    final normalizedInput = input.toLowerCase().trim();
    double confidence = 0.0;
    
    // Extract amount
    final amount = extractAmount(input);
    if (amount != null) confidence += 0.3;

    // Extract description
    final description = extractDescription(input, amount);
    
    // Detect type (Credit/Debit)
    final type = detectType(normalizedInput);
    if (type != null) confidence += 0.2;

    // Detect category
    final category = detectCategory(normalizedInput, availableCategories);
    if (category != null) confidence += 0.3;

    // If we have amount and description, increase confidence
    if (amount != null && description.isNotEmpty) confidence += 0.2;

    // Date defaults to today
    final date = DateTime.now();

    return ParsedTransaction(
      amount: amount,
      category: category,
      type: type ?? 'Debit', // Default to Debit if not detected
      description: description,
      date: date,
      confidence: min(confidence, 1.0),
      rawInput: input,
    );
  }

  /// Extract numeric amount from input string
  /// Supports: ₹500, 500, 250.50, etc.
  static double? extractAmount(String input) {
    // Remove currency symbols and clean the string
    final cleaned = input.replaceAll(RegExp(r'[₹,$€£]'), '').trim();
    
    // Try to find a number (integer or decimal)
    final regex = RegExp(r'(\d+(?:\.\d+)?)');
    final matches = regex.allMatches(cleaned);
    
    if (matches.isEmpty) return null;
    
    // Get the last match (usually the amount comes after description)
    final lastMatch = matches.last;
    final amountStr = lastMatch.group(1);
    
    if (amountStr == null) return null;
    
    final amount = double.tryParse(amountStr);
    return amount;
  }

  /// Extract clean description from input
  /// Removes amount and currency symbols
  static String extractDescription(String input, double? amount) {
    String description = input;
    
    // Remove currency symbols
    description = description.replaceAll(RegExp(r'[₹,$€£]'), ' ');
    
    // Remove the amount if found
    if (amount != null) {
      final amountStr = amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
      description = description.replaceAll(RegExp(r'\b' + RegExp.escape(amountStr) + r'\b'), '');
    }
    
    // Remove extra whitespace
    description = description.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove common words that don't add meaning
    final stopWords = ['for', 'of', 'the', 'a', 'an', 'got', 'paid', 'spent'];
    final words = description.split(' ');
    final filteredWords = words.where((w) => 
      w.isNotEmpty && !stopWords.contains(w.toLowerCase())
    ).toList();
    
    description = filteredWords.join(' ');
    
    // Capitalize first letter
    if (description.isNotEmpty) {
      description = description[0].toUpperCase() + description.substring(1);
    }
    
    return description.isEmpty ? 'Transaction' : description;
  }

  /// Detect transaction type (Credit/Debit) from input
  static String? detectType(String normalizedInput) {
    // Tokenize for robust matching and also keep substring fallback
    final tokens = normalizedInput.split(RegExp(r'[^a-z0-9₹]+')).where((t) => t.isNotEmpty).toList();

    bool containsKeyword(List<String> keywords) {
      for (final k in keywords) {
        final kw = k.toLowerCase();
        // Exact token match
        if (tokens.contains(kw)) return true;
        // Substring fallback (for phrases like 'paid me' or 'upi received')
        if (normalizedInput.contains(kw)) return true;
      }
      return false;
    }

    if (containsKeyword(creditKeywords)) return 'Credit';
    if (containsKeyword(debitKeywords)) return 'Debit';
    return null;
  }

  /// Detect category from input keywords
  static String? detectCategory(String normalizedInput, List<String> availableCategories) {
    // First, check if any available category matches directly
    for (final category in availableCategories) {
      final categoryLower = category.toLowerCase();
      if (normalizedInput.contains(categoryLower)) {
        return category;
      }
    }
    
    // Then check keyword mappings - match keywords to user's actual categories
    // Create a mapping of keywords to potential category names
    final keywordToCategoryMap = <String, String>{};
    
    // Map each keyword group to matching user categories
    for (final entry in categoryKeywords.entries) {
      final baseCategoryName = entry.key.toLowerCase();
      final keywords = entry.value;
      
      // Find user categories that match this keyword group
      for (final userCategory in availableCategories) {
        final userCategoryLower = userCategory.toLowerCase();
        
        // Check if user category name contains words related to this keyword group
        // For example: "Food & Dining" matches "Food", "Restaurant" matches "Food"
        bool isMatch = false;
        
        // Direct match (e.g., user has "Food" category)
        if (userCategoryLower == baseCategoryName) {
          isMatch = true;
        }
        // Partial match (e.g., user has "Food & Dining", matches "Food")
        else if (userCategoryLower.contains(baseCategoryName) || 
                 baseCategoryName.contains(userCategoryLower.split(' ')[0])) {
          isMatch = true;
        }
        // Check for common variations
        else {
          final variations = {
            'food': ['restaurant', 'dining', 'meal', 'cafe', 'canteen'],
            'transport': ['travel', 'commute', 'vehicle', 'car', 'bike'],
            'shopping': ['retail', 'store', 'market', 'purchase'],
            'income': ['salary', 'earning', 'revenue'],
            'entertainment': ['fun', 'leisure', 'recreation'],
            'bills': ['utilities', 'payment', 'due'],
            'health': ['medical', 'fitness', 'wellness'],
            'education': ['learning', 'study', 'school'],
            'general': ['misc', 'other', 'personal'],
          };
          
          final variationsForCategory = variations[baseCategoryName] ?? [];
          for (final variation in variationsForCategory) {
            if (userCategoryLower.contains(variation) || variation.contains(userCategoryLower.split(' ')[0])) {
              isMatch = true;
              break;
            }
          }
        }
        
        if (isMatch) {
          // Map all keywords in this group to the user's category
          for (final keyword in keywords) {
            keywordToCategoryMap[keyword] = userCategory;
          }
        }
      }
    }
    
    // Check if any keyword matches the input
    for (final entry in keywordToCategoryMap.entries) {
      final keyword = entry.key;
      final matchedCategory = entry.value;
      
      if (normalizedInput.contains(keyword)) {
        return matchedCategory;
      }
    }
    
    return null;
  }

  /// Get suggested categories based on partial input
  static List<String> getSuggestions(String partialInput, List<String> availableCategories) {
    if (partialInput.trim().isEmpty) return [];
    
    final normalized = partialInput.toLowerCase();
    final suggestions = <String>[];
    
    // Check direct category matches (user's actual categories)
    for (final category in availableCategories) {
      if (category.toLowerCase().startsWith(normalized) || 
          category.toLowerCase().contains(normalized)) {
        suggestions.add(category);
      }
    }
    
    // Check keyword matches - map keywords to user's categories
    final keywordToCategoryMap = <String, String>{};
    
    for (final entry in categoryKeywords.entries) {
      final baseCategoryName = entry.key.toLowerCase();
      final keywords = entry.value;
      
      for (final userCategory in availableCategories) {
        final userCategoryLower = userCategory.toLowerCase();
        
        bool isMatch = false;
        if (userCategoryLower == baseCategoryName) {
          isMatch = true;
        } else if (userCategoryLower.contains(baseCategoryName) || 
                   baseCategoryName.contains(userCategoryLower.split(' ')[0])) {
          isMatch = true;
        } else {
          final variations = {
            'food': ['restaurant', 'dining', 'meal', 'cafe', 'canteen'],
            'transport': ['travel', 'commute', 'vehicle', 'car', 'bike'],
            'shopping': ['retail', 'store', 'market', 'purchase'],
            'income': ['salary', 'earning', 'revenue'],
            'entertainment': ['fun', 'leisure', 'recreation'],
            'bills': ['utilities', 'payment', 'due'],
            'health': ['medical', 'fitness', 'wellness'],
            'education': ['learning', 'study', 'school'],
            'general': ['misc', 'other', 'personal'],
          };
          
          final variationsForCategory = variations[baseCategoryName] ?? [];
          for (final variation in variationsForCategory) {
            if (userCategoryLower.contains(variation) || variation.contains(userCategoryLower.split(' ')[0])) {
              isMatch = true;
              break;
            }
          }
        }
        
        if (isMatch) {
          for (final keyword in keywords) {
            keywordToCategoryMap[keyword] = userCategory;
          }
        }
      }
    }
    
    // Check if input matches any keyword and suggest corresponding user category
    for (final entry in keywordToCategoryMap.entries) {
      final keyword = entry.key;
      final matchedCategory = entry.value;
      
      if ((keyword.startsWith(normalized) || keyword.contains(normalized)) && 
          !suggestions.contains(matchedCategory)) {
        suggestions.add(matchedCategory);
      }
    }
    
    return suggestions.take(5).toList(); // Limit to 5 suggestions
  }
}

