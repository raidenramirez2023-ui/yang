import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _restaurantNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _taxRateController = TextEditingController();

  String _currency = 'PHP';
  bool _darkMode = false;
  bool _notifications = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _restaurantNameController.text = prefs.getString('restaurant_name') ?? 'Yang Chow Restaurant';
      _addressController.text = prefs.getString('address') ?? 'Pagsanjan, Laguna';
      _phoneController.text = prefs.getString('phone') ?? '+63 2 123-4567';
      _emailController.text = prefs.getString('email') ?? 'info@yangchow.com';
      _taxRateController.text = prefs.getString('tax_rate') ?? '12.0';
      _currency = prefs.getString('currency') ?? 'PHP';
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _notifications = prefs.getBool('notifications') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isLoading = true);
    
    try {
      await prefs.setString('restaurant_name', _restaurantNameController.text);
      await prefs.setString('address', _addressController.text);
      await prefs.setString('phone', _phoneController.text);
      await prefs.setString('email', _emailController.text);
      await prefs.setString('tax_rate', _taxRateController.text);
      await prefs.setString('currency', _currency);
      await prefs.setBool('dark_mode', _darkMode);
      await prefs.setBool('notifications', _notifications);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved successfully!'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Restaurant Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              'Manage your restaurant information and preferences',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.mediumGrey,
              ),
            ),
            const SizedBox(height: AppTheme.xl),

            // Restaurant Information Section
            _buildSectionCard(
              context,
              title: 'Restaurant Information',
              icon: Icons.restaurant,
              child: _buildRestaurantForm(),
            ),
            const SizedBox(height: AppTheme.xl),

            // Business Settings Section
            _buildSectionCard(
              context,
              title: 'Business Settings',
              icon: Icons.business,
              child: _buildBusinessSettings(),
            ),
            const SizedBox(height: AppTheme.xl),

            // App Settings Section
            _buildSectionCard(
              context,
              title: 'Application Settings',
              icon: Icons.settings,
              child: _buildAppSettings(),
            ),
            const SizedBox(height: AppTheme.xxl),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveSettings,
                icon: _isLoading ? null : const Icon(Icons.save),
                label: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                      ),
                    )
                  : const Text('Save All Settings'),
              ),
            ),
            const SizedBox(height: AppTheme.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: Column(
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLg),
                topRight: Radius.circular(AppTheme.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryRed, size: 28),
                const SizedBox(width: AppTheme.lg),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormField(
          label: 'Restaurant Name',
          controller: _restaurantNameController,
          icon: Icons.restaurant,
        ),
        const SizedBox(height: AppTheme.lg),
        _buildFormField(
          label: 'Address',
          controller: _addressController,
          icon: Icons.location_on,
        ),
        const SizedBox(height: AppTheme.lg),
        _buildFormField(
          label: 'Phone Number',
          controller: _phoneController,
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppTheme.lg),
        _buildFormField(
          label: 'Email Address',
          controller: _emailController,
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildBusinessSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormField(
          label: 'Tax Rate (%)',
          controller: _taxRateController,
          icon: Icons.percent,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppTheme.lg),
        Text(
          'Currency',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppTheme.md),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.lightGrey),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currency,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.lg,
                vertical: AppTheme.md,
              ),
              items: const ['PHP', 'USD', 'EUR'].map((currency) {
                return DropdownMenuItem(
                  value: currency,
                  child: Row(
                    children: [
                      const Icon(Icons.attach_money, size: 20),
                      const SizedBox(width: AppTheme.md),
                      Text(currency, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _currency = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppSettings() {
    return Column(
      children: [
        _buildSettingsTile(
          icon: Icons.dark_mode,
          title: 'Dark Mode',
          subtitle: 'Enable dark theme',
          value: _darkMode,
          onChanged: (value) => setState(() => _darkMode = value),
        ),
        Divider(color: AppTheme.lightGrey, height: AppTheme.xl),
        _buildSettingsTile(
          icon: Icons.notifications,
          title: 'Push Notifications',
          subtitle: 'Receive app notifications',
          value: _notifications,
          onChanged: (value) => setState(() => _notifications = value),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppTheme.md),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.md),
        decoration: BoxDecoration(
          color: value ? AppTheme.primaryRed.withOpacity(0.1) : AppTheme.lightGrey,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Icon(icon, color: value ? AppTheme.primaryRed : AppTheme.mediumGrey),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryRed,
      ),
    );
  }

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }
}