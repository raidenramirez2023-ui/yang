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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _restaurantNameController.text = prefs.getString('restaurant_name') ?? 'YANG CHOW RESTAURANT';
      _addressController.text = prefs.getString('address') ?? 'CLA Town Center Mall, Ground floor near mall entrance, Pagsanjan, Laguna';
      _phoneController.text = prefs.getString('phone') ?? '501-9179 / +63 975-041-9671';
      _emailController.text = prefs.getString('email') ?? 'info@yangchow.com';
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Settings saved successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
            margin: const EdgeInsets.all(AppTheme.lg),
            elevation: 4,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error saving settings: $e')),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
            margin: const EdgeInsets.all(AppTheme.lg),
            elevation: 4,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(Icons.settings_rounded, color: AppTheme.primaryRed, size: 32),
              ),
              const SizedBox(width: AppTheme.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restaurant Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Manage your restaurant information',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.xxl),

          // Restaurant Information Section
          _buildSectionCard(
            context,
            title: 'General Information',
            subtitle: 'This information will be displayed publicly',
            child: _buildRestaurantForm(),
          ),
          const SizedBox(height: AppTheme.xxl),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56, // Taller, modern button
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _saveSettings,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                elevation: 0,
              ),
              icon: _isLoading ? null : const Icon(Icons.save_rounded),
              label: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
          ),
          const SizedBox(height: AppTheme.xl),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.all(AppTheme.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mediumGrey,
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                const Divider(),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: const EdgeInsets.only(left: AppTheme.xl, right: AppTheme.xl, bottom: AppTheme.xl),
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
          icon: Icons.storefront_rounded,
        ),
        const SizedBox(height: AppTheme.xl),
        _buildFormField(
          label: 'Address & Location',
          controller: _addressController,
          icon: Icons.location_on_rounded,
          maxLines: 2,
        ),
        const SizedBox(height: AppTheme.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Phone Number',
                controller: _phoneController,
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: AppTheme.xl),
            Expanded(
              child: _buildFormField(
                label: 'Email Address',
                controller: _emailController,
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(color: AppTheme.mediumGrey.withValues(alpha: 0.5)),
            prefixIcon: maxLines > 1 
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Icon(icon, color: AppTheme.mediumGrey),
                  )
                : Icon(icon, color: AppTheme.mediumGrey),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.05),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: maxLines > 1 ? AppTheme.lg : AppTheme.md, // More padding for modern feel
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              borderSide: BorderSide.none, // Removes the harsh outline for a softer look
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              borderSide: BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}