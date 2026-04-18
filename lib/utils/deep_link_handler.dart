import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/pages/simple_password_reset.dart';

class DeepLinkHandler {
  static void handleDeepLink(BuildContext context, String? link) {
    if (link == null) return;
    
    debugPrint('Deep link received: $link');
    
    // Check if it's a password reset link
    if (link.contains('reset-password') || link.contains('recovery')) {
      debugPrint('Password reset link detected');
      
      // Navigate to password reset page
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/reset-password',
        (route) => false,
      );
    }
  }
  
  static Future<void> checkForPasswordResetSession(BuildContext context) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        debugPrint('User authenticated from deep link');
        
        // Check if this is a password recovery session
        final user = session.user;
        if (user != null) {
          // Navigate to password reset page
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/reset-password',
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking auth session: $e');
    }
  }
}
