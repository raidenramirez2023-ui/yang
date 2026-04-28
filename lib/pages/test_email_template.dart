import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';

class TestEmailTemplate extends StatefulWidget {
  const TestEmailTemplate({super.key});

  @override
  State<TestEmailTemplate> createState() => _TestEmailTemplateState();
}

class _TestEmailTemplateState extends State<TestEmailTemplate> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _testResult = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _testEmailReset() async {
    if (_emailController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _testResult = 'Sending test email...\n';
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );

      setState(() {
        _testResult += 'Email sent successfully!\n\n';
        _testResult += 'Check your email for the reset link.\n';
        _testResult += 'The link should redirect to: /reset-password\n\n';
        _testResult += 'Template should show:\n';
        _testResult += '- "Reset Password" button\n';
        _testResult += '- Direct reset link (no OTP)\n';
        _testResult += '- Yang Chow Restaurant branding';
      });

    } on AuthException catch (e) {
      setState(() {
        _testResult += 'Error: ${e.message}\n';
        _testResult += 'Status Code: ${e.statusCode ?? 'No code'}\n\n';
        if (e.message.contains('unexpected_failure')) {
          _testResult += 'This is likely an email service issue.\n';
          _testResult += 'Check SendGrid configuration.\n';
        }
      });
    } catch (e) {
      setState(() {
        _testResult += 'Other error: $e\n';
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Test Email Template'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Email input
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Test Email Address',
                hintText: 'Enter your email to test',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            
            // Test button
            ElevatedButton(
              onPressed: _isLoading ? null : _testEmailReset,
              child: _isLoading 
                ? CircularProgressIndicator(color: Colors.white)
                : Text('Send Test Email'),
            ),
            SizedBox(height: 16),
            
            // Test result
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Result:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _testResult.isEmpty ? 'Click "Send Test Email" to start...' : _testResult,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // Instructions
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email Template Checklist:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text('Subject: "Reset Your Password - Yang Chow Restaurant"'),
                  Text('Body: Uses {{ .ConfirmationURL }} (not {{ .Token }})'),
                  Text('Button: Styled "Reset Password" button'),
                  Text('Link: Direct reset link (no OTP)'),
                  Text('Branding: Yang Chow Restaurant'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
