import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../HomePage.dart';
import '../services/hybrid_storage_service.dart';
import '../utils/category_name.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _categoryController = TextEditingController();
  List<SpendingCategory> _userCategories = [];
  final List<SpendingCategory> _suggestedCategories = [
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
      if (mounted) {
        setState(() {
          _userCategories = raw.map((m) => SpendingCategory(
            name: (m['name'] ?? '').toString(), 
            icon: Icons.category, 
            color: Colors.grey
          )).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _addCustomCategory() {
    final text = _categoryController.text.trim();
    if (text.isEmpty) return;
    if (categoryNameExists(
      _userCategories.map((category) => category.name),
      text,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A category with this name already exists')),
      );
      return;
    }

    final newCategory = SpendingCategory(
      name: text,
      icon: Icons.category,
      color: Colors.grey,
      isCustom: true,
    );

    setState(() {
      _userCategories.add(newCategory);
      _categoryController.clear();
    });
  }

  void _removeCategory(SpendingCategory category) {
    showDialog<bool>(
      context: context,
      builder: (ctx)=> AlertDialog(
        backgroundColor: const Color(0xFF0E1F1F),
        title: Text('Delete category?', style: GoogleFonts.nunito(color: Colors.white)),
        content: Text('This will remove the category and its budget.', style: GoogleFonts.nunito(color: Colors.white70)),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
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
    if (categoryNameExists(
      _userCategories.map((existing) => existing.name),
      category.name,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A category with this name already exists')),
      );
      return;
    }
    setState(() {
      _userCategories.add(category);
    });
  }

  Future<void> _saveChanges() async {
    if (_userCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categories updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Homepage()),
        (Route<dynamic> route) => false,
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update categories: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
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
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF032221), Color(0xFF0C4340), Color(0xFF032221)],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Your Spending Categories',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Customize your spending categories. Add, remove, or modify them as needed.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _categoryController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Add custom category...',
                                hintStyle: const TextStyle(color: Colors.white60),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.white30),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.white30),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.green),
                                ),
                              ),
                              onSubmitted: (_) => _addCustomCategory(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _addCustomCategory,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (_userCategories.isNotEmpty) ...[
                        Text(
                          'Current Categories (${_userCategories.length})',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _userCategories.map((category) {
                            return _buildCategoryChip(category, true);
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      Text(
                        'Available Categories',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Click to add these categories to your list:',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestedCategories
                            .where((category) => !categoryNameExists(
                                  _userCategories.map((existing) => existing.name),
                                  category.name,
                                ))
                            .map((category) {
                          return _buildCategoryChip(category, false);
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCategoryChip(SpendingCategory category, bool isCurrent) {
    return InkWell(
      onTap: isCurrent ? null : () => _addSuggestedCategory(category),
      onLongPress: isCurrent ? () => _removeCategory(category) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent ? category.color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isCurrent ? category.color : Colors.white.withOpacity(0.2),
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
            const SizedBox(width: 8),
            Text(
              category.name,
              style: GoogleFonts.nunito(
                color: isCurrent ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _removeCategory(category),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 16,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpendingCategory &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}
