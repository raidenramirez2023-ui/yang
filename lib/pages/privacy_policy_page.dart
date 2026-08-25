import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/utils/app_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _boldStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 14,
    color: Colors.black87,
    height: 1.6,
  );

  static const _normalStyle = TextStyle(
    fontSize: 14,
    color: Colors.black54,
    height: 1.6,
  );

  static const _sectionTitleStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: Colors.black87,
  );

  static const _subSectionTitleStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 15,
    color: Colors.black87,
  );

  Widget _buildBullet(List<TextSpan> spans) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: _normalStyle),
          Expanded(child: RichText(text: TextSpan(children: spans))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Privacy Policy',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last updated: August 25, 2026',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Intro paragraph
                const Text(
                  'Yang Chow Restaurant ("we", "our", or "us") operates the Yang Chow mobile application (the "App"). '
                  'This Privacy Policy explains how we collect, use, disclose, and protect your information when you use our App.',
                  style: _normalStyle,
                ),

                // ── 1. Information We Collect ──
                const SizedBox(height: 28),
                const Text('1. Information We Collect',
                    style: _sectionTitleStyle),
                const SizedBox(height: 14),

                // 1.1 Personal Information
                const Text('1.1 Personal Information',
                    style: _subSectionTitleStyle),
                const SizedBox(height: 8),
                _buildBullet([
                  const TextSpan(
                      text: 'Contact Information: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'Firstname, Lastname, Phone Number, Valid ID, and Valid Email Address (if you voluntarily provide it).',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(
                      text: 'Account Information: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'username, password, and any profile details you choose to share.',
                      style: _normalStyle),
                ]),

                // 1.2 Non-Personal Information
                const SizedBox(height: 14),
                const Text('1.2 Non-Personal Information',
                    style: _subSectionTitleStyle),
                const SizedBox(height: 8),
                _buildBullet([
                  const TextSpan(
                      text: 'Device Information: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'device model, operating system version, unique device identifiers, and IP address.',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(text: 'Usage Data: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'interaction logs, crash reports, analytics events, and performance data.',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(text: 'Location Data: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'approximate location derived from IP address or device GPS (only if you enable location services).',
                      style: _normalStyle),
                ]),

                // ── 2. How We Use Your Information ──
                const SizedBox(height: 28),
                const Text('2. How We Use Your Information',
                    style: _sectionTitleStyle),
                const SizedBox(height: 10),
                _buildBullet([
                  const TextSpan(
                      text: 'Provide & Maintain the Service: ',
                      style: _boldStyle),
                  const TextSpan(
                      text:
                          'to operate, personalize, and improve the App.',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(text: 'Communication: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'to send you updates, security alerts, support messages, and marketing communications (you may opt-out).',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(
                      text: 'Analytics & Research: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'to analyze usage patterns, diagnose technical issues, and develop new features.',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(
                      text: 'Legal Compliance: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'to comply with legal obligations, enforce our Terms of Service, and protect against fraud.',
                      style: _normalStyle),
                ]),

                // ── 3. Sharing & Disclosure ──
                const SizedBox(height: 28),
                const Text('3. Sharing & Disclosure',
                    style: _sectionTitleStyle),
                const SizedBox(height: 10),
                const Text('We may share your information with:',
                    style: _normalStyle),
                const SizedBox(height: 6),
                _buildBullet([
                  const TextSpan(
                      text: 'Service Providers: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'third-party vendors that help us host, analyze, or support the App (e.g., cloud providers, analytics services). They are contractually obligated to protect your data.',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(
                      text: 'Legal Requirements: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'when required by law, subpoena, or governmental request.',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(
                      text: 'Business Transfers: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'in connection with a merger, acquisition, or sale of assets, provided the acquiring entity agrees to honor this Privacy Policy.',
                      style: _normalStyle),
                ]),
                const SizedBox(height: 10),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'We ', style: _normalStyle),
                      TextSpan(text: 'do not sell', style: _boldStyle),
                      TextSpan(
                          text:
                              ' your personal information to third parties.',
                          style: _normalStyle),
                    ],
                  ),
                ),

                // ── 4. Data Retention ──
                const SizedBox(height: 28),
                const Text('4. Data Retention', style: _sectionTitleStyle),
                const SizedBox(height: 10),
                const Text(
                  'We retain your personal data only for as long as necessary to fulfill the purposes outlined in this Privacy Policy, '
                  'unless a longer retention period is required or permitted by law.',
                  style: _normalStyle,
                ),

                // ── 5. Your Rights & Choices ──
                const SizedBox(height: 28),
                const Text('5. Your Rights & Choices',
                    style: _sectionTitleStyle),
                const SizedBox(height: 10),
                _buildBullet([
                  const TextSpan(
                      text: 'Access & Correction: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'you may request access to, correction of, or deletion of your personal data.',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(text: 'Opt-Out: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'you can opt out of marketing communications via the unsubscribe link in our emails or by adjusting app settings.',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(
                      text: 'Location Services: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'you can disable location permissions in your device settings.',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(
                      text: 'Data Portability: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'upon request, we can provide a copy of your personal data in a machine-readable format.',
                      style: _normalStyle),
                ]),

                // ── 6. Security ──
                const SizedBox(height: 28),
                const Text('6. Security', style: _sectionTitleStyle),
                const SizedBox(height: 10),
                const Text(
                  'We implement reasonable technical and organizational measures to protect your data against unauthorized access, alteration, '
                  'disclosure, or destruction. However, no method of transmission over the internet is 100% secure.',
                  style: _normalStyle,
                ),

                // ── 7. Children's Privacy ──
                const SizedBox(height: 28),
                const Text("7. Children's Privacy",
                    style: _sectionTitleStyle),
                const SizedBox(height: 10),
                const Text(
                  'The App is not directed at children under the age of 18, and we do not knowingly collect personal information from minors. '
                  'Users must be 18 years of age or older to use this App.',
                  style: _normalStyle,
                ),

                // ── 8. International Transfers ──
                const SizedBox(height: 28),
                const Text('8. International Transfers',
                    style: _sectionTitleStyle),
                const SizedBox(height: 10),
                const Text(
                  'Your information may be transferred to, and processed in, countries outside your residence, which may have different data protection laws. '
                  'We will ensure appropriate safeguards are in place.',
                  style: _normalStyle,
                ),

                // ── 9. Changes to This Privacy Policy ──
                const SizedBox(height: 28),
                const Text('9. Changes to This Privacy Policy',
                    style: _sectionTitleStyle),
                const SizedBox(height: 10),
                const Text(
                  'We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy '
                  'within the App and updating the "Last updated" date.',
                  style: _normalStyle,
                ),

                // ── 10. Contact Us ──
                const SizedBox(height: 28),
                const Text('10. Contact Us', style: _sectionTitleStyle),
                const SizedBox(height: 10),
                const Text(
                  'If you have any questions about this Privacy Policy, please contact us at:',
                  style: _normalStyle,
                ),
                const SizedBox(height: 6),
                _buildBullet([
                  const TextSpan(text: 'Email: ', style: _boldStyle),
                  const TextSpan(
                      text: 'bsit-ycprms@yc-pagsanjan.site',
                      style: _normalStyle),
                ]),
                _buildBullet([
                  const TextSpan(text: 'Address: ', style: _boldStyle),
                  const TextSpan(
                      text:
                          'CLA TOWN CENTER MALL, Ground floor near at mall entrance.',
                      style: _normalStyle),
                ]),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '© 2026 Yang Chow Restaurant. All rights reserved.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
