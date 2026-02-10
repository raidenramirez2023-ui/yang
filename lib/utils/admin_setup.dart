import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSetup {
  static Future<void> setupAdminAccount() async {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    
    try {
      // Sign in with the admin credentials
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: 'adminpagsanjan@gmail.com',
        password: 'yangchowpagsanjan2026',
      );
      
      print('✅ Admin authenticated: ${userCredential.user?.email}');
      
      // Check if user already exists in Firestore
      QuerySnapshot existingUser = await _firestore
          .collection('users')
          .where('email', isEqualTo: 'adminpagsanjan@gmail.com')
          .get();
      
      if (existingUser.docs.isEmpty) {
        // Add admin user to Firestore
        await _firestore.collection('users').add({
          'email': 'adminpagsanjan@gmail.com',
          'role': 'Admin',
          'name': 'System Administrator',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
        
        print('✅ Admin user added to Firestore database');
      } else {
        print('ℹ️ Admin user already exists in Firestore');
        
        // Update existing user to ensure role is correct
        await _firestore
            .collection('users')
            .doc(existingUser.docs.first.id)
            .update({'role': 'Admin'});
        
        print('✅ Admin role updated in Firestore');
      }
      
      print('🎉 Admin setup complete! You can now login as Admin.');
      
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.message}');
    } catch (e) {
      print('❌ Firestore Error: $e');
    }
  }
}
