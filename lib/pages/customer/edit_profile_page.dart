import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String _initialFirstName = '';
  String _initialLastName = '';
  String _initialPhone = '';

  bool _isSaving = false;
  XFile? _pickedFile;
  Uint8List? _pickedFileBytes;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    String firstName = user.userMetadata?['firstname'] ?? '';
    String lastName = user.userMetadata?['lastname'] ?? '';

    // Fallback if data is missing or user has legacy full_name
    if (firstName.isEmpty && lastName.isEmpty) {
      String fullName =
          user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '';
      if (fullName.isNotEmpty) {
        final parts = fullName.split(' ');
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }
    }

    _firstNameController.text = firstName;
    _initialFirstName = firstName;
    _lastNameController.text = lastName;
    _initialLastName = lastName;
    _emailController.text = user.email ?? '';
    _phoneNumberController.text = user.userMetadata?['phone'] ?? '';
    _initialPhone = user.userMetadata?['phone'] ?? '';
  }

  bool _isValidName(String name) {
    if (name.length < 2 || name.length > 50) return false;
    if (RegExp(r"[\s\-'’]{2,}").hasMatch(name)) return false;
    if (RegExp(r"^[\s\-'’]|[\s\-'’]$").hasMatch(name)) return false;
    if (RegExp(r"(.)\1{2,}", caseSensitive: false).hasMatch(name)) return false;
    return RegExp(r"^[\p{L}\p{M}\s\-'’]+$", unicode: true).hasMatch(name);
  }

  String _formatToTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().replaceAllMapped(
      RegExp(r"(^|[\s\-'’])(\p{L}\p{M}*)", unicode: true),
      (Match m) => '${m[1]}${m[2]!.toUpperCase()}',
    );
  }

  bool _isValidPhoneNumber(String phone) {
    return phone.length == 11 &&
        phone.startsWith('09') &&
        RegExp(r'^[0-9]+$').hasMatch(phone);
  }

  Future<bool> _confirmPhoneNumberChange(
    String previousPhone,
    String currentPhone,
  ) async {
    if (previousPhone == currentPhone) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Phone Number Changed'),
            content: Text(
              previousPhone.isEmpty
                  ? 'You added a new phone number. Do you want to save it?'
                  : 'You want to change your phone number from $previousPhone to $currentPhone. Do you want to save this update?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D1B1E),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('Upload Image'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    if (source != null) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedFile = picked;
          _pickedFileBytes = bytes;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final currentAvatarUrl = user.userMetadata?['avatar_url'] as String?;
    final hasNoExistingPhoto =
        currentAvatarUrl == null || currentAvatarUrl.isEmpty;

    if (hasNoExistingPhoto && _pickedFile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile photo is required.'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final currentFirstName = _firstNameController.text.trim();
    final currentLastName = _lastNameController.text.trim();
    final currentPhone = _phoneNumberController.text.trim();
    final formattedFirstName = _formatToTitleCase(currentFirstName);
    final formattedLastName = _formatToTitleCase(currentLastName);
    final hasImageChanged = _pickedFile != null;
    final hasNameChanged =
        formattedFirstName != _initialFirstName ||
        formattedLastName != _initialLastName;
    final hasPhoneChanged = currentPhone != _initialPhone;

    if (formattedFirstName.isEmpty || !_isValidName(formattedFirstName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Please enter a valid first name.'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (formattedLastName.isEmpty || !_isValidName(formattedLastName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Please enter a valid last name.'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (!_isValidPhoneNumber(currentPhone)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Please enter a valid phone number (11 digits, starting with 09).',
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    _firstNameController.text = formattedFirstName;
    _lastNameController.text = formattedLastName;

    if (hasPhoneChanged) {
      final confirmed = await _confirmPhoneNumberChange(
        _initialPhone,
        currentPhone,
      );
      if (!confirmed) return;
    }

    if (!hasImageChanged && !hasNameChanged && !hasPhoneChanged) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? avatarUrl = currentAvatarUrl;

      // ── 1. Upload new image if picked ──────────────────────────────────
      if (_pickedFile != null) {
        final userId = user.id;
        final fileExt = _pickedFile!.path.split('.').last;
        final fileName = 'avatar_$userId.$fileExt';
        final filePath = fileName;

        // Upload to 'avatars' bucket (Rethrows error if bucket is missing)
        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(
              filePath,
              _pickedFileBytes!,
              fileOptions: const FileOptions(upsert: true),
            );

        // Get public URL
        avatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(filePath);
      }

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      // ── 2. Update user metadata ─────────────────────────────────────────
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'firstname': firstName,
            'lastname': lastName,
            'avatar_url': avatarUrl,
            'phone': currentPhone,
            // Keep full_name for backward compatibility if needed
            'full_name': '$firstName $lastName'.trim(),
            'name': '$firstName $lastName'.trim(),
          },
        ),
      );

      // ── 3. Update public users table ────────────────────────────────────
      await Supabase.instance.client
          .from('users')
          .update({
            'firstname': firstName,
            'lastname': lastName,
            'phone': currentPhone,
            'avatar_url': avatarUrl,
          })
          .eq('email', user.email ?? '');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile updated successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Return to account page after success
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final initial = _firstNameController.text.isNotEmpty
        ? _firstNameController.text[0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9FF),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1D1B1E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF1D1B1E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ── Profile Photo ──────────────────────────────────────────
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Avatar circle
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFDAD6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _pickedFileBytes != null
                          ? Image.memory(
                              _pickedFileBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1D1B1E),
                                      ),
                                    ),
                                  ),
                            )
                          : (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1D1B1E),
                                      ),
                                    ),
                                  ),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D1B1E),
                                ),
                              ),
                            ),
                    ),

                    // Camera badge
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Label & Change Picture
              const Text(
                'PROFILE PHOTO',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B6B6B),
                ),
              ),

              const SizedBox(height: 32),

              // ── First Name ──────────────────────────────────────────────
              _buildFieldLabel('FIRST NAME'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(
                  hint: 'Enter your first name',
                  suffixIcon: Icons.person_outline_rounded,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'First name is required'
                    : null,
              ),

              const SizedBox(height: 20),

              // ── Last Name ──────────────────────────────────────────────
              _buildFieldLabel('LAST NAME'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(
                  hint: 'Enter your last name',
                  suffixIcon: Icons.person_outline_rounded,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Last name is required'
                    : null,
              ),

              const SizedBox(height: 20),

              // ── Phone Number ────────────────────────────────────────────
              _buildFieldLabel('PHONE NUMBER'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: _fieldDecoration(
                  hint: 'Enter your phone number',
                  suffixIcon: Icons.phone_outlined,
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Phone number is required';
                  if (!_isValidPhoneNumber(value)) {
                    return 'Phone number must be 11 digits and start with 09';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ── Email Address ──────────────────────────────────────────
              _buildFieldLabel('EMAIL ADDRESS'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: true, // email change requires re-verification
                style: TextStyle(color: Colors.grey.shade600),
                decoration: _fieldDecoration(
                  hint: 'Your email address',
                  suffixIcon: Icons.mail_outline_rounded,
                ),
              ),

              const SizedBox(height: 20),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: 32,
          top: 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FF),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B6B6B),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      suffixIcon: Icon(suffixIcon, color: Colors.grey.shade400, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}
