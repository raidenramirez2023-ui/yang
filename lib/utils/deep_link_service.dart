import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/pages/simple_password_reset.dart';

class DeepLinkService {
  static void handlePasswordReset(BuildContext context, String? link) {
    if (link == null) return;
    
    debugPrint('Deep link received: $link');
    
    // Check if it's a password reset link
    if (link.contains('reset-password') || 
        link.contains('recovery') || 
        link.contains('auth/recovery') ||
        link.contains('token')) {
      debugPrint('Password reset link detected');
      
      // Navigate to password reset page
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/reset-password',
        (route) => false,
      );
    }
  }
  
  static Future<bool> checkForPasswordResetSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        debugPrint('User authenticated from deep link: ${session.user?.email}');
        
        // Check if this is a password recovery session
        // Supabase creates a temporary session for password recovery
        final user = session.user;
        if (user != null) {
          return true; // This is a recovery session
        }
      }
    } catch (e) {
      debugPrint('Error checking auth session: $e');
    }
    return false;
  }
  
  static void navigateToPasswordReset(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/reset-password',
      (route) => false,
    );
  }
}
