import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.phone_android_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Text(
                  'Confirm Phone Update',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              previousPhone.isEmpty
                  ? 'You added $currentPhone as your phone number. Do you want to save it?'
                  : 'You are updating your phone number from $previousPhone to $currentPhone. Do you want to continue?',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkGrey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.mediumGrey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Confirm', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Upload Profile Photo',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose where to select your new profile picture',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.mediumGrey,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: const Color(0xFFF8FAFC),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.forestGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppTheme.forestGreen, size: 20),
                  ),
                  title: Text('Choose from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('Pick an existing photo or image', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mediumGrey)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.mediumGrey),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: const Color(0xFFF8FAFC),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warmGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFB45309), size: 20),
                  ),
                  title: Text('Take a New Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('Use your camera to snap a picture', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mediumGrey)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.mediumGrey),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                const SizedBox(height: 12),
              ],
            ),
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
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              Text('Please enter a valid phone number (11 digits, starting with 09).'),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

        // Upload to 'avatars' bucket
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
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Return to account page after success
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _isChanged {
    return _firstNameController.text.trim() != _initialFirstName ||
        _lastNameController.text.trim() != _initialLastName ||
        _phoneNumberController.text.trim() != _initialPhone ||
        _pickedFile != null;
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange),
            const SizedBox(width: 10),
            Text('Unsaved Changes', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: Text(
          'You have unsaved changes in your profile. Are you sure you want to discard them?',
          style: GoogleFonts.inter(color: AppTheme.darkGrey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Keep Editing', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.forestGreen)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Discard', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final initial = _firstNameController.text.isNotEmpty
        ? _firstNameController.text[0].toUpperCase()
        : 'U';
    final isMobile = ResponsiveUtils.isMobile(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (!_isChanged) {
          Navigator.of(context).pop();
          return;
        }
        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.navColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () async {
              if (!_isChanged) {
                Navigator.of(context).pop();
              } else {
                final result = await _showUnsavedChangesDialog();
                if (result == true && context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          title: Text(
            'Edit Profile',
            style: GoogleFonts.lora(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: isMobile ? 18 : 20,
              letterSpacing: 0.3,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 20 : 28,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Profile Photo Hero Card ─────────────────────────────
                      _buildProfileHeroCard(avatarUrl, initial, isMobile),

                      const SizedBox(height: 24),

                      // ── Personal Information Card ───────────────────────────
                      _buildPersonalInfoCard(isMobile),

                      const SizedBox(height: 20),

                      // ── Contact Information Card ────────────────────────────
                      _buildContactInfoCard(isMobile),

                      const SizedBox(height: 32),

                      // ── Bottom Action Buttons ───────────────────────────────
                      _buildActionButtons(isMobile),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile Hero & Photo Section ──────────────────────────────────────────
  Widget _buildProfileHeroCard(String? avatarUrl, String initial, bool isMobile) {
    final displayName = (_firstNameController.text.trim().isNotEmpty ||
            _lastNameController.text.trim().isNotEmpty)
        ? '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
        : 'Yang Chow Customer';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gradient Accent Top Banner
          Container(
            height: isMobile ? 70 : 85,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF14332E), Color(0xFF1E4A42), Color(0xFF2B5B52)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
            ),
          ),

          // Avatar overlapping top banner
          Transform.translate(
            offset: Offset(0, isMobile ? -42 : -48),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Main Avatar Circle
                    Container(
                      width: isMobile ? 96 : 108,
                      height: isMobile ? 96 : 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _pickedFileBytes != null
                            ? Image.memory(_pickedFileBytes!, fit: BoxFit.cover)
                            : (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildInitialAvatar(initial),
                                    loadingBuilder: (_, child, progress) =>
                                        progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : _buildInitialAvatar(initial),
                      ),
                    ),

                    // Camera Action Badge
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.goldGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: AppTheme.darkBrownText, size: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Live Display Name
                Text(
                  displayName,
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 17 : 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkGrey,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Change Photo Button
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.warmGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_rounded, color: Color(0xFFB45309), size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'Change Photo',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      color: const Color(0xFF14332E),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.lora(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppTheme.warmGold,
          ),
        ),
      ),
    );
  }

  // ── Personal Information Card ─────────────────────────────────────────────
  Widget _buildPersonalInfoCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.badge_outlined,
            title: 'Personal Details',
          ),
          const SizedBox(height: 18),

          // Side-by-side on wide screens, stacked on mobile
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('First Name', isRequired: true),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
                        decoration: _fieldDecoration(
                          hint: 'e.g. Juan',
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'First name is required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Last Name', isRequired: true),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
                        decoration: _fieldDecoration(
                          hint: 'e.g. Dela Cruz',
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _buildFieldLabel('First Name', isRequired: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _firstNameController,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
              decoration: _fieldDecoration(
                hint: 'e.g. Juan',
                prefixIcon: Icons.person_outline_rounded,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'First name is required' : null,
            ),
            const SizedBox(height: 18),
            _buildFieldLabel('Last Name', isRequired: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _lastNameController,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
              decoration: _fieldDecoration(
                hint: 'e.g. Dela Cruz',
                prefixIcon: Icons.person_outline_rounded,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
            ),
          ],
        ],
      ),
    );
  }

  // ── Contact Information Card ──────────────────────────────────────────────
  Widget _buildContactInfoCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.contact_phone_outlined,
            title: 'Contact Information',
          ),
          const SizedBox(height: 18),

          // Phone Number Field
          _buildFieldLabel('Mobile Phone Number', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneNumberController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
            decoration: _fieldDecoration(
              hint: '09XXXXXXXXX',
              prefixIcon: Icons.phone_android_rounded,
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Phone number is required';
              if (!_isValidPhoneNumber(value)) {
                return 'Phone number must be 11 digits starting with 09';
              }
              return null;
            },
          ),

          const SizedBox(height: 18),

          // Email Address (Read-only with Verified badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('Account Email Address'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 11),
                    const SizedBox(width: 4),
                    Text(
                      'Primary & Verified',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            readOnly: true,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            decoration: _fieldDecoration(
              hint: 'your.email@example.com',
              prefixIcon: Icons.lock_outline_rounded,
              isReadOnly: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────────
  Widget _buildActionButtons(bool isMobile) {
    final hasChanges = _isChanged;

    return Row(
      children: [
        // Cancel / Discard
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      if (!_isChanged) {
                        Navigator.of(context).pop();
                      } else {
                        final result = await _showUnsavedChangesDialog();
                        if (result == true && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                foregroundColor: AppTheme.darkGrey,
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGrey,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 14),

        // Save Changes Button
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_isSaving || !hasChanges) ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.forestGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFF94A3B8),
                elevation: hasChanges ? 4 : 0,
                shadowColor: AppTheme.forestGreen.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Save Changes',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helper Sub-Widgets ────────────────────────────────────────────────────
  Widget _buildCardHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.forestGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.forestGreen, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefixIcon,
    bool isReadOnly = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: isReadOnly ? const Color(0xFF94A3B8) : AppTheme.forestGreen,
        size: 19,
      ),
      filled: true,
      fillColor: isReadOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.forestGreen, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.errorRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.errorRed, width: 1.8),
      ),
    );
  }
}
