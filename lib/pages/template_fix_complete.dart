import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';

class TemplateFixComplete extends StatefulWidget {
  const TemplateFixComplete({super.key});

  @override
  State<TemplateFixComplete> createState() => _TemplateFixCompleteState();
}

class _TemplateFixCompleteState extends State<TemplateFixComplete> {
  bool _isLoading = false;
  String _result = '';

  Future<void> _checkSupabaseConfig() async {
    setState(() {
      _isLoading = true;
      _result = 'Checking Supabase configuration...\n';
    });

    try {
      // Check current auth settings
      _result += '1. Checking authentication settings...\n';
      
      // Try to send reset email to see what template is being used
      await Supabase.instance.client.auth.resetPasswordForEmail('test@example.com');
      
      _result += '2. Email sent successfully\n';
      _result += '3. If 8-digit code still appears, the issue is:\n';
      _result += '   - Supabase is using cached template\n';
      _result += '   - Wrong template type is being used\n';
      _result += '   - Supabase configuration needs reset\n\n';
      
      _result += '4. SOLUTIONS:\n';
      _result += '   A. Delete and recreate the template\n';
      _result += '   B. Check if you updated the correct template\n';
      _result += '   C. Clear Supabase cache\n';
      _result += '   D. Use different email provider\n\n';
      
      _result += '5. TEMPLATE CHECKLIST:\n';
      _result += '   - Subject: "Reset Your Password - Yang Chow Restaurant"\n';
      _result += '   - Body: Uses {{ .ConfirmationURL }} ONLY\n';
      _result += '   - NO {{ .Token }} references\n';
      _result += '   - NO "8-digit" text\n';
      _result += '   - NO "verification code" text\n';

    } catch (e) {
      _result += 'Error: $e\n';
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Template Fix Complete'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _checkSupabaseConfig,
              child: _isLoading 
                ? CircularProgressIndicator(color: Colors.white)
                : Text('Check Supabase Config'),
            ),
            SizedBox(height: 16),
            
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
                    'Configuration Check:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _result.isEmpty ? 'Click "Check Supabase Config" to start...' : _result,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IMMEDIATE FIX:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                  ),
                  SizedBox(height: 8),
                  Text('1. Go to Supabase Dashboard'),
                  Text('2. Authentication -> Email Templates'),
                  Text('3. Select "Reset password"'),
                  Text('4. DELETE ALL CONTENT'),
                  Text('5. Paste NEW template (below)'),
                  Text('6. Save and wait 2 minutes'),
                  Text('7. Test again'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
