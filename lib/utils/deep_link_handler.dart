import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        debugPrint('User authenticated from deep link: ${session.user.email}');
        
        // Check if this is a password recovery session
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/reset-password',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error checking auth session: $e');
    }
  }
}
