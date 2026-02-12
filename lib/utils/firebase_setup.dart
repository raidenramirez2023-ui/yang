import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseSetup {
  static Future<void> setupFirestoreDatabase() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    
    try {
      // Create users collection if it doesn't exist
      // Check if admin user already exists
      QuerySnapshot existingAdmin = await firestore
          .collection('users')
          .where('email', isEqualTo: 'adminpagsanjan@gmail.com')
          .get();
      
      if (existingAdmin.docs.isEmpty) {
        // Add admin user to Firestore
        await firestore.collection('users').add({
          'email': 'adminpagsanjan@gmail.com',
          'role': 'Admin',
          'name': 'System Administrator',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'department': 'Management',
        });
        
        print('✅ Admin user created in Firestore');
      } else {
        // Update existing admin to ensure correct role
        await firestore
            .collection('users')
            .doc(existingAdmin.docs.first.id)
            .update({
              'role': 'Admin',
              'name': 'System Administrator',
              'isActive': true,
              'department': 'Management',
            });
        
        print('✅ Admin user updated in Firestore');
      }
      
      // Create sample collections for testing
      await _createSampleData();
      
      print('🎉 Firestore database setup complete!');
      
    } catch (e) {
      print('❌ Error setting up Firestore: $e');
      rethrow;
    }
  }
  
  static Future<void> _createSampleData() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    
    try {
      // Create sample menu items
      CollectionReference menuItems = firestore.collection('menu_items');
      
      // Check if menu items already exist
      QuerySnapshot existingItems = await menuItems.limit(1).get();
      
      if (existingItems.docs.isEmpty) {
        List<Map<String, dynamic>> sampleMenu = [
          {
            'name': 'Yang Chow Fried Rice',
            'category': 'Rice',
            'price': 150.00,
            'description': 'Special fried rice with mixed vegetables and meat',
            'isAvailable': true,
            'imageUrl': '',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'name': 'Sweet and Sour Pork',
            'category': 'Pork',
            'price': 220.00,
            'description:': 'Crispy pork with sweet and sour sauce',
            'isAvailable': true,
            'imageUrl': '',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'name': 'Beef Broccoli',
            'category': 'Beef',
            'price': 250.00,
            'description': 'Tender beef with fresh broccoli',
            'isAvailable': true,
            'imageUrl': '',
            'createdAt': FieldValue.serverTimestamp(),
          },
        ];
        
        for (var item in sampleMenu) {
          await menuItems.add(item);
        }
        
        print('✅ Sample menu items created');
      }
      
      // Create sample categories
      CollectionReference categories = firestore.collection('categories');
      
      QuerySnapshot existingCategories = await categories.limit(1).get();
      
      if (existingCategories.docs.isEmpty) {
        List<Map<String, dynamic>> sampleCategories = [
          {'name': 'Rice', 'description': 'Fried Rice varieties'},
          {'name': 'Pork', 'description': 'Pork dishes'},
          {'name': 'Beef', 'description': 'Beef dishes'},
          {'name': 'Chicken', 'description': 'Chicken dishes'},
          {'name': 'Vegetables', 'description': 'Vegetable dishes'},
          {'name': 'Noodles', 'description': 'Noodle dishes'},
          {'name': 'Soup', 'description': 'Soup items'},
          {'name': 'Beverages', 'description': 'Drinks'},
        ];
        
        for (var category in sampleCategories) {
          await categories.add({
            ...category,
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
          });
        }
        
        print('✅ Sample categories created');
      }
      
    } catch (e) {
      print('❌ Error creating sample data: $e');
    }
  }
}
