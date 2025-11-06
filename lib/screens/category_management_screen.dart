import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../HomePage.dart';
import '../services/hybrid_storage_service.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _categoryController = TextEditingController();
  List<SpendingCategory> _userCategories = [];
  List<SpendingCategory> _suggestedCategories = [
    SpendingCategory(name: 'Food', icon: Icons.restaurant, color: Colors.orange),
    SpendingCategory(name: 'Stationary', icon: Icons.edit, color: Colors.blue),
    SpendingCategory(name: 'Outings', icon: Icons.local_activity, color: Colors.purple),
    SpendingCategory(name: 'Travel', icon: Icons.directions_car, color: Colors.green),
    SpendingCategory(name: 'Shopping', icon: Icons.shopping_bag, color: Colors.pink),
    SpendingCategory(name: 'Healthcare', icon: Icons.medical_services, color: Colors.red),
    SpendingCategory(name: 'Education', icon: Icons.school, color: Colors.indigo),
    SpendingCategory(name: 'Entertainment', icon: Icons.movie, color: Colors.teal),
    SpendingCategory(name: 'Transport', icon: Icons.directions_bus, color: Colors.cyan),
    SpendingCategory(name: 'Bills', icon: Icons.receipt, color: Colors.brown),
  ];
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserCategories();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadUserCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final raw = await HybridStorageService.getCategories();
      setState(() {
        _userCategories = raw.map((m) => SpendingCategory(name: (m['name'] ?? '').toString(), icon: Icons.category, color: Colors.grey)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  void _addCustomCategory() {
    if (_categoryController.text.trim().isNotEmpty) {
      final newCategory = SpendingCategory(
        name: _categoryController.text.trim(),
        icon: Icons.category,
        color: Colors.grey,
        isCustom: true,
      );
      
      setState(() {
        _userCategories.add(newCategory);
        _categoryController.clear();
      });
    }
  }

  void _removeCategory(SpendingCategory category) {
    showDialog<bool>(
      context: context,
      builder: (ctx)=> AlertDialog(
        title: Text('Delete category?'),
        content: Text('This will remove the category and its budget.'),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: Text('Cancel')),
          TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ).then((ok) async {
      if (ok == true) {
        setState(() {
          _userCategories.remove(category);
        });
        await HybridStorageService.removeCategoryByName(category.name);
      }
    });
  }

  void _addSuggestedCategory(SpendingCategory category) {
    if (!_userCategories.contains(category)) {
      setState(() {
        _userCategories.add(category);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_userCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please keep at least one spending category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await HybridStorageService.saveCategories(_userCategories.map((c)=>{'name': c.name}).toList());

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Categories updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate back to dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => Homepage()),
        (Route<dynamic> route) => false,
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update categories: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF032221),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF032221), Colors.black],
            ),
          ),
          child: AppBar(
            title: Text(
              'Manage Categories',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.nunito(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'Your Spending Categories',
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Customize your spending categories. Add, remove, or modify them as needed.',
                    style: GoogleFonts.nunito(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Custom Category Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _categoryController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Add custom category...',
                            hintStyle: TextStyle(color: Colors.white60),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.green),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _addCustomCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Current Categories
                  if (_userCategories.isNotEmpty) ...[
                    Text(
                      'Current Categories (${_userCategories.length})',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _userCategories.map((category) {
                        return _buildCategoryChip(category, true);
                      }).toList(),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Available Categories
                  Text(
                    'Available Categories',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Click to add these categories to your list:',
                    style: GoogleFonts.nunito(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedCategories
                        .where((category) => !_userCategories.contains(category))
                        .map((category) {
                      return _buildCategoryChip(category, false);
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryChip(SpendingCategory category, bool isCurrent) {
    return InkWell(
      onTap: isCurrent ? null : () => _addSuggestedCategory(category),
      onLongPress: isCurrent ? () => _removeCategory(category) : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent ? category.color.withOpacity(0.3) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isCurrent ? category.color : Colors.white.withOpacity(0.3),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              color: isCurrent ? category.color : Colors.white70,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              category.name,
              style: GoogleFonts.nunito(
                color: isCurrent ? category.color : Colors.white,
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isCurrent) ...[
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: InkWell(
                  onTap: () => _removeCategory(category),
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SpendingCategory {
  final String name;
  final IconData icon;
  final Color color;
  final bool isCustom;

  SpendingCategory({
    required this.name,
    required this.icon,
    required this.color,
    this.isCustom = false,
  });

  factory SpendingCategory.fromJson(Map<String, dynamic> json) {
    return SpendingCategory(
      name: json['name'] ?? '',
      icon: IconData(int.parse(json['icon_name'] ?? '0'), fontFamily: 'MaterialIcons'),
      color: Color(json['color'] ?? 0xFF808080),
      isCustom: json['is_custom'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpendingCategory &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}
