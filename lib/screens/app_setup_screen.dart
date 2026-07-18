import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../HomePage.dart';
import '../services/hybrid_storage_service.dart';

class AppSetupScreen extends StatefulWidget {
  final String userEmail;
  
  const AppSetupScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<AppSetupScreen> createState() => _AppSetupScreenState();
}

class _AppSetupScreenState extends State<AppSetupScreen> {
  final _categoryController = TextEditingController();
  final List<SpendingCategory> _selectedCategories = [];
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
  
  bool _isLoading = false;
  int _currentStep = 0;
  final int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    // Pre-select some common categories
    _selectedCategories.addAll(_suggestedCategories.take(5));
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  void _addCustomCategory() {
    final text = _categoryController.text.trim();
    if (text.isNotEmpty) {
      final newCategory = SpendingCategory(
        name: text,
        icon: Icons.category,
        color: Colors.grey,
        isCustom: true,
      );
      
      setState(() {
        _selectedCategories.add(newCategory);
        _categoryController.clear();
      });
    }
  }

  void _removeCategory(SpendingCategory category) {
    setState(() {
      _selectedCategories.remove(category);
    });
  }

  void _toggleCategory(SpendingCategory category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  Future<void> _saveAppSetup() async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one spending category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final payload = _selectedCategories.map((c) => {
        'name': c.name,
      }).toList();
      await HybridStorageService.saveCategories(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App setup completed successfully!'),
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
          content: Text('Failed to save app setup: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF032221),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF032221), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildProgressBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: size.height * 0.7),
                    child: _buildCurrentStep(),
                  ),
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: GoogleFonts.nunito(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                '${((_currentStep + 1) / _totalSteps * 100).round()}%',
                style: GoogleFonts.nunito(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildCategoriesStep();
      case 2:
        return _buildFinalStep();
      default:
        return _buildWelcomeStep();
    }
  }

  Widget _buildWelcomeStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.settings,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        Text(
          'Set Up Your App',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Let\'s personalize your Vaultic experience by setting up spending categories and preferences.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _buildSetupItem(Icons.category, 'Spending Categories', 'Organize your expenses'),
              const SizedBox(height: 16),
              _buildSetupItem(Icons.trending_up, 'Budget Tracking', 'Monitor your spending'),
              const SizedBox(height: 16),
              _buildSetupItem(Icons.notifications, 'Smart Notifications', 'Stay updated'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSetupItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.nunito(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle, color: Colors.green, size: 20),
      ],
    );
  }

  Widget _buildCategoriesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Spending Categories',
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the categories you want to organize your spending. You can add custom categories too!',
          style: GoogleFonts.nunito(
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

        if (_selectedCategories.isNotEmpty) ...[
          Text(
            'Selected Categories (${_selectedCategories.length})',
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
            children: _selectedCategories.map((category) {
              return _buildCategoryChip(category, true);
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        Text(
          'Suggested Categories',
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
          children: _suggestedCategories.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return _buildCategoryChip(category, isSelected);
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCategoryChip(SpendingCategory category, bool isSelected) {
    return InkWell(
      onTap: () => _toggleCategory(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? category.color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? category.color : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              color: isSelected ? category.color : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              category.name,
              style: GoogleFonts.nunito(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (category.isCustom && isSelected) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _removeCategory(category),
                child: const Icon(
                  Icons.close,
                  color: Colors.red,
                  size: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinalStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        Text(
          'Almost Done!',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'You\'ve selected ${_selectedCategories.length} spending categories. Your app is ready to help you track your finances!',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 40),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected Categories:',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedCategories.take(10).map((category) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: category.color.withOpacity(0.3)),
                    ),
                    child: Text(
                      category.name,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_selectedCategories.length > 10) ...[
                const SizedBox(height: 8),
                Text(
                  '+${_selectedCategories.length - 10} more',
                  style: GoogleFonts.nunito(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Previous',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: 16),
          
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep == _totalSteps - 1 ? _saveAppSetup : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Setting Up...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _currentStep == _totalSteps - 1 ? 'Finish Setup' : 'Next',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
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
