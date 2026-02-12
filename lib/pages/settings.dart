import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Controllers
  final TextEditingController _restaurantNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _taxRateController = TextEditingController();

  // Settings
  String _currency = 'PHP';
  String _timezone = 'Asia/Manila';
  bool _enableNotifications = true;
  bool _enablePrintReceipt = true;
  bool _enableInventoryAlerts = true;

  bool _enableTax = true;

  String _language = 'English';
  String _theme = 'Dark';
  bool _autoBackup = true;

  // Temp values for dropdowns before saving
  String _tempTheme = 'Dark';
  String _tempLanguage = 'English';
  String _tempCurrency = 'PHP';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Load saved settings
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _restaurantNameController.text = prefs.getString('restaurantName') ?? 'Yang Chow Restaurant';
      _addressController.text = prefs.getString('address') ?? '123 Main St, Quezon City';
      _phoneController.text = prefs.getString('phone') ?? '+63 2 1234 5678';
      _emailController.text = prefs.getString('email') ?? 'info@yangchow.com';
      _taxRateController.text = prefs.getString('taxRate') ?? '12.0';

      _currency = prefs.getString('currency') ?? 'PHP';
      _timezone = prefs.getString('timezone') ?? 'Asia/Manila';
      _enableNotifications = prefs.getBool('enableNotifications') ?? true;
      _enablePrintReceipt = prefs.getBool('enablePrintReceipt') ?? true;
      _enableInventoryAlerts = prefs.getBool('enableInventoryAlerts') ?? true;
      _enableTax = prefs.getBool('enableTax') ?? true;

      _language = prefs.getString('language') ?? 'English';
      _theme = prefs.getString('theme') ?? 'Dark';
      _autoBackup = prefs.getBool('autoBackup') ?? true;

      _tempTheme = _theme;
      _tempLanguage = _language;
      _tempCurrency = _currency;

      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('restaurantName', _restaurantNameController.text);
    await prefs.setString('address', _addressController.text);
    await prefs.setString('phone', _phoneController.text);
    await prefs.setString('email', _emailController.text);
    await prefs.setString('taxRate', _taxRateController.text);

    await prefs.setString('currency', _tempCurrency);
    await prefs.setString('timezone', _timezone);
    await prefs.setBool('enableNotifications', _enableNotifications);
    await prefs.setBool('enablePrintReceipt', _enablePrintReceipt);
    await prefs.setBool('enableInventoryAlerts', _enableInventoryAlerts);
    await prefs.setBool('enableTax', _enableTax);

    await prefs.setString('language', _tempLanguage);
    await prefs.setString('theme', _tempTheme);
    await prefs.setBool('autoBackup', _autoBackup);

    setState(() {
      _theme = _tempTheme;
      _language = _tempLanguage;
      _currency = _tempCurrency;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _restaurantNameController.text = 'Yang Chow Restaurant';
      _addressController.text = '123 Main St, Quezon City';
      _phoneController.text = '+63 2 1234 5678';
      _emailController.text = 'info@yangchow.com';
      _taxRateController.text = '12.0';

      _currency = _tempCurrency = 'PHP';
      _timezone = 'Asia/Manila';
      _enableNotifications = true;
      _enablePrintReceipt = true;
      _enableInventoryAlerts = true;
      _enableTax = true;

      _language = _tempLanguage = 'English';
      _theme = _tempTheme = 'Dark';
      _autoBackup = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings reset to default!'),
        backgroundColor: Colors.orange,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = _tempTheme == 'Dark' ||
        (_tempTheme == 'System' &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    Color getBackground() => isDark ? const Color(0xFF121212) : Colors.grey.shade50;
    Color getCard() => isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color getText() => isDark ? Colors.white : Colors.black87;
    Color getIcon() => isDark ? Colors.white70 : Colors.grey.shade800;
    Color getBorder() => isDark ? Colors.white24 : Colors.grey.shade300;
    Color getField() => isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Scaffold(
      backgroundColor: getBackground(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildSectionCard(
              title: 'Restaurant Information',
              icon: Icons.store,
              cardColor: getCard(),
              textColor: getText(),
              iconColor: getIcon(),
              borderColor: getBorder(),
              fieldColor: getField(),
              children: [
                _buildTextField('Restaurant Name', _restaurantNameController, Icons.store, getText(), getIcon(), getBorder(), getField()),
                _buildTextField('Address', _addressController, Icons.location_on, getText(), getIcon(), getBorder(), getField()),
                _buildTextField('Phone', _phoneController, Icons.phone, getText(), getIcon(), getBorder(), getField()),
                _buildTextField('Email', _emailController, Icons.email, getText(), getIcon(), getBorder(), getField()),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Business Settings',
              icon: Icons.business,
              cardColor: getCard(),
              textColor: getText(),
              iconColor: getIcon(),
              borderColor: getBorder(),
              fieldColor: getField(),
              children: [
                _buildDropdownField(
                  'Currency',
                  _tempCurrency,
                  ['PHP', 'USD', 'EUR'],
                  Icons.attach_money,
                  getText(),
                  getIcon(),
                  getBorder(),
                  getField(),
                  (val) => setState(() => _tempCurrency = val),
                ),
                _buildDropdownField(
                  'Timezone',
                  _timezone,
                  ['Asia/Manila', 'UTC+8', 'Asia/Singapore'],
                  Icons.access_time,
                  getText(),
                  getIcon(),
                  getBorder(),
                  getField(),
                  (val) => setState(() => _timezone = val),
                ),
                _buildSwitchField('Enable Notifications', _enableNotifications, Icons.notifications, getText(), getIcon(), (val) => setState(() => _enableNotifications = val)),
                _buildSwitchField('Print Receipt', _enablePrintReceipt, Icons.print, getText(), getIcon(), (val) => setState(() => _enablePrintReceipt = val)),
                _buildSwitchField('Inventory Alerts', _enableInventoryAlerts, Icons.warning, getText(), getIcon(), (val) => setState(() => _enableInventoryAlerts = val)),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Tax Settings',
              icon: Icons.receipt_long,
              cardColor: getCard(),
              textColor: getText(),
              iconColor: getIcon(),
              borderColor: getBorder(),
              fieldColor: getField(),
              children: [
                _buildSwitchField('Enable Tax', _enableTax, Icons.calculate, getText(), getIcon(), (val) => setState(() => _enableTax = val)),
                if (_enableTax)
                  _buildTextField('Tax Rate (%)', _taxRateController, Icons.percent, getText(), getIcon(), getBorder(), getField()),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'System Settings',
              icon: Icons.settings,
              cardColor: getCard(),
              textColor: getText(),
              iconColor: getIcon(),
              borderColor: getBorder(),
              fieldColor: getField(),
              children: [
                _buildDropdownField(
                  'Language',
                  _tempLanguage,
                  ['English', 'Filipino', 'Chinese'],
                  Icons.language,
                  getText(),
                  getIcon(),
                  getBorder(),
                  getField(),
                  (val) => setState(() => _tempLanguage = val),
                ),
                _buildDropdownField(
                  'Theme',
                  _tempTheme,
                  ['Light', 'Dark', 'System'],
                  Icons.palette,
                  getText(),
                  getIcon(),
                  getBorder(),
                  getField(),
                  (val) => setState(() => _tempTheme = val),
                ),
                _buildSwitchField('Auto Backup', _autoBackup, Icons.backup, getText(), getIcon(), (val) => setState(() => _autoBackup = val)),
              ],
            ),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 20),
            Text(
              'Yang Chow POS System v1.0.0',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required Color cardColor,
    required Color textColor,
    required Color iconColor,
    required Color borderColor,
    required Color fieldColor,
  }) {
    return Card(
      elevation: 2,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.red.shade600),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon,
      Color textColor, Color iconColor, Color borderColor, Color fillColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: iconColor),
          prefixIcon: Icon(icon, color: iconColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red.shade600)),
          filled: true,
          fillColor: fillColor,
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    IconData icon,
    Color textColor,
    Color iconColor,
    Color borderColor,
    Color fillColor,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: iconColor),
          prefixIcon: Icon(icon, color: iconColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red.shade600),
          ),
          filled: true,
          fillColor: fillColor,
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item, style: TextStyle(color: textColor)),
        )).toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    );
  }

  Widget _buildSwitchField(
    String label,
    bool value,
    IconData icon,
    Color textColor,
    Color iconColor,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: textColor))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.red.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetSettings,
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Default'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
