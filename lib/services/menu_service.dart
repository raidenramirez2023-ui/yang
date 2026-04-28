import 'package:flutter/material.dart';
import '../models/menu_item.dart';

class MenuService {
  static final List<String> categories = [
    'Yangchow Family Bundles',
    'Vegetables',
    'Special Noodles',
    'Soup',
    'Seafood',
    'Roast and Soy Specialties',
    'Pork',
    'Noodles',
    'Mami or Noodles',
    'Hot Pot Specialties',
    'Fried Rice or Rice',
    'Dimsum',
    'Congee',
    'Chicken',
    'Beef',
    'Appetizer',
  ];

  static final Map<String, List<String>> categoryImages = {
    'Yangchow Family Bundles': [
      'assets/images/YC1.png',
      'assets/images/YC2.png',
      'assets/images/YC3.jpg',
      'assets/images/YC4.jpg',
      'assets/images/Overloadmeals.png',
    ],
    'Vegetables': [
      'assets/images/VBLwOS.jpg',
      'assets/images/BFOyster.png',
      'assets/images/TPOyster.png',
      'assets/images/SPSF.jpg',
      'assets/images/VBSCwBF.jpg',
      'assets/images/Lohanchay.png',
      'assets/images/ChopsueyGuisado.jpg',
      'assets/images/VCKwG.jpg',
    ],
    'Special Noodles': [
      'assets/images/YCSNoodles.png',
      'assets/images/YCFriedRice.jpg',
      'assets/images/PancitCLM.jpg',
    ],
    'Soup': [
      'assets/images/CCSoup.jpg',
      'assets/images/HSSoup.jpg',
      'assets/images/HototaySoup.jpg',
      'assets/images/MBwEWSoup.png',
      'assets/images/NSoupQE.png',
      'assets/images/SSSoup.jpg',
      'assets/images/CMCSoup.jpg',
    ],
    'Seafood': [
      'assets/images/SPS.jpg',
      'assets/images/BFwSquid.jpg',
      'assets/images/BFShrimp.jpg',
      'assets/images/SFFwOS.jpg',
      'assets/images/FFilletSA.jpg',
      'assets/images/SSFF.jpg',
      'assets/images/FFwTS.jpg',
      'assets/images/FFwBF.jpg',
      'assets/images/FFwSC.jpg',
      'assets/images/HSSalad.jpg',
      'assets/images/CamaronRebusado.jpg',
      'assets/images/SwSE.jpg',
    ],
    'Roast and Soy Specialties': [
      'assets/images/LechonMacau.jpg',
      'assets/images/RPAsado.jpg',
      'assets/images/RoastChicken.jpg',
      'assets/images/CC3.png',
      'assets/images/CC5.png',
      'assets/images/SoyedTaufo.png',
    ],
    'Pork': [
      'assets/images/SSP.jpg',
      'assets/images/SOkSauce.jpg',
      'assets/images/LumpiangShanghai.jpg',
      'assets/images/PatatimCuapao.jpg',
      'assets/images/SAwT.png',
      'assets/images/MPwL.jpg',
      'assets/images/SwSP.jpg',
      'assets/images/KwLM.jpg',
    ],
    'Noodles': [
      'assets/images/PancitCanton.jpg',
      'assets/images/SeafoodCanton.jpg',
      'assets/images/SBHofan.jpg',
      'assets/images/BihonGuisado.jpg',
      'assets/images/BirthdayNoodles.png',
      'assets/images/CNoodleMM.jpg',
      'assets/images/CNMS.png',
      'assets/images/BCMG.jpg',
      'assets/images/PancitCLM.jpg',
    ],
    'Mami or Noodles': [
      'assets/images/RPAN.png',
      'assets/images/BBNoodles.png',
      'assets/images/WantonNoodles.jpg',
      'assets/images/BBWantonN.jpg',
      'assets/images/WantonSoup.png',
      'assets/images/FishballNoodles.png',
      'assets/images/SquidballNoodles.png',
      'assets/images/LobsterballNoodles.png',
    ],
    'Hot Pot Specialties': [
      'assets/images/MPEHotPot.png',
      'assets/images/FFTHotPot.jpg',
      'assets/images/LKHotPot.png',
      'assets/images/STHotPot.jpg',
      'assets/images/BBRHotPot.jpg',
      'assets/images/RPAwTHotPot.png',
    ],
    'Fried Rice or Rice': [
      'assets/images/YCFriedRice.jpg',
      'assets/images/BeefFriedRice.png',
      'assets/images/CSFFriedRice.jpg',
      'assets/images/GarlicFriedRice.jpg',
      'assets/images/PineappleFriedRice.jpg',
      'assets/images/SteamedRiceP.jpg',
      'assets/images/SteamedRiceC.jpg',
    ],
    'Dimsum': [
      'assets/images/SwS.jpg',
      'assets/images/QESiomai.png',
      'assets/images/WantonDumplings.jpg',
      'assets/images/SFDumpling.png',
      'assets/images/AsadoSiopao.png',
      'assets/images/BBSiopao.jpg',
      'assets/images/TausiSpareribs.jpg',
      'assets/images/CuapaoMantau.jpg',
      'assets/images/ChickenFeet.jpg',
      'assets/images/Hakaw.png',
      'assets/images/SpinachDumpling.jpg',
      'assets/images/SpecialSiopao.png',
    ],
    'Congee': [
      'assets/images/PCEC.png',
      'assets/images/PLCongee.jpg',
      'assets/images/SeafoodCongee.png',
      'assets/images/SFCongee.jpg',
      'assets/images/BBCongee.jpg',
      'assets/images/SCC.png',
      'assets/images/CenturyEgg.jpg',
      'assets/images/FreshEgg.jpg',
    ],
    'Chicken': [
      'assets/images/ButteredChicken.jpg',
      'assets/images/YCFChicken.jpg',
      'assets/images/SSChicken.jpg',
      'assets/images/FCwSEY.jpg',
      'assets/images/LemonChicken.jpg',
      'assets/images/SCwCNQE.jpg',
    ],
    'Beef': [
      'assets/images/BeefBLK.jpg',
      'assets/images/BeefBF.jpg',
      'assets/images/BAmpalaya.jpg',
      'assets/images/BSCS.jpg',
      'assets/images/BeefBP.png',
      'assets/images/BeefGP.png',
      'assets/images/BSE.jpeg',
      'assets/images/SBM.jpg',
    ],
    'Appetizer': [
      'assets/images/JellyFCE.jpg',
      'assets/images/JellyFish.jpg',
      'assets/images/Calamares.jpg',
    ],
    'default': ['assets/images/YCFriedRice.jpg'],
  };

  static Map<String, List<MenuItem>> getMenu() {
    final Map<String, List<MenuItem>> menu = {for (var cat in categories) cat: []};

    // Helper to select fallback image
    final Map<String, int> categoryImageIndex = {};
    String nextImage(String category) {
      final images = categoryImages[category] ?? categoryImages['default']!;
      final index = categoryImageIndex[category] ?? 0;
      final img = images[index];
      categoryImageIndex[category] = (index + 1) % images.length;
      return img;
    }

    MenuItem item(String name, double price, String category, Color color, {String? customImagePath, String? description}) {
      return MenuItem(
        name: name,
        price: price,
        category: category,
        fallbackImagePath: customImagePath ?? nextImage(category),
        color: color,
        customImagePath: customImagePath,
        description: description,
      );
    }

    // --- Data Extraction from shared_pos_widget.dart ---
    
    // Yangchow Family Bundles
    menu['Yangchow Family Bundles']!.addAll([
      item('YangChow 1', 1880.80, 'Yangchow Family Bundles', Colors.orange, customImagePath: 'assets/images/YC1.png', description: 'Our signature feast: Fried Rice, Chicken, Sweet & Sour Pork, and more.'),
      item('YangChow 2', 1880.80, 'Yangchow Family Bundles', Colors.deepOrange, customImagePath: 'assets/images/YC2.png', description: 'A perfect family mix of noodles, seafood, and classic Chinese roasts.'),
      item('YangChow 3', 3588.80, 'Yangchow Family Bundles', Colors.deepOrange, customImagePath: 'assets/images/YC3.jpg', description: 'Grand celebration set featuring our finest seafood and premium meats.'),
      item('YangChow 4', 4588.80, 'Yangchow Family Bundles', Colors.deepOrange, customImagePath: 'assets/images/YC4.jpg', description: 'The ultimate banquet experience for large groups and special events.'),
      item('Overload Meal', 298.80, 'Yangchow Family Bundles', Colors.deepOrange, customImagePath: 'assets/images/Overloadmeals.png', description: 'Satisfying solo meal with a variety of our best-selling flavors.'),
    ]);

    // Vegetables
    menu['Vegetables']!.addAll([
      item('Broccoli Leaves with Oyster Sauce', 278.80, 'Vegetables', Colors.blue, customImagePath: 'assets/images/VBLwOS.jpg', description: 'Fresh, vibrant broccoli leaves sautéed in a rich, savory oyster sauce.'),
      item('Broccoli Flower with Oyster Sauce', 368.80, 'Vegetables', Colors.orange, customImagePath: 'assets/images/BFOyster.png', description: 'Healthy and crunchy broccoli flowers with our special oyster glaze.'),
      item('Taiwan Pechay with Oyster Sauce', 288.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/TPOyster.png', description: 'Tender Taiwan pechay perfectly paired with savory oyster sauce.'),
      item('Spinach/Polanchay Stir Fried', 298.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/SPSF.jpg', description: 'Quick-fired spinach with garlic and traditional seasonings.'),
      item('Braised Sea Cucumber with Broccoli Flower', 328.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/VBSCwBF.jpg', description: 'A premium vegetable dish with tender sea cucumber and broccoli.'),
      item('Lohanchay', 298.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/Lohanchay.png', description: 'A traditional mixed vegetable delight for a healthy choice.'),
      item('Chopsuey Guisado', 338.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/ChopsueyGuisado.jpg', description: 'Stir-fried mixed vegetables with meats and seafood.'),
      item('Chinese Kangkong with Garlic', 238.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/VCKwG.jpg', description: 'Simple yet flavorful kangkong sautéed with aromatic garlic.'),
    ]);

    // Special Noodles
    menu['Special Noodles']!.addAll([
      item('YC Special Noodles', 298.80, 'Special Noodles', Colors.amber, customImagePath: 'assets/images/YCSNoodles.png', description: 'Our chef\'s special noodle creation with a unique blend of flavors.'),
    ]);

    // Soup
    menu['Soup']!.addAll([
      item('Chicken Corn Soup', 308.80, 'Soup', Colors.yellow, customImagePath: 'assets/images/CCSoup.jpg', description: 'Comforting creamy corn soup with tender chicken bits.'),
      item('Hot & Sour Soup', 338.80, 'Soup', Colors.red, customImagePath: 'assets/images/HSSoup.jpg', description: 'Tangy and spicy soup that awakens the senses.'),
      item('Hototay Soup', 338.80, 'Soup', Colors.purple, customImagePath: 'assets/images/HototaySoup.jpg', description: 'A rich mixed meat and vegetable soup with egg.'),
      item('Minced Beef with Egg White Soup', 308.80, 'Soup', Colors.purple, customImagePath: 'assets/images/MBwEWSoup.png', description: 'Velvety soup with fine minced beef and smooth egg whites.'),
      item('Nido Soup with Quail Egg', 328.80, 'Soup', Colors.brown, customImagePath: 'assets/images/NSoupQE.png', description: 'A classic Chinese delicacy soup served with quail eggs.'),
      item('Spinach Seafood Soup', 338.80, 'Soup', Colors.purple, customImagePath: 'assets/images/SSSoup.jpg', description: 'Nutritious green soup packed with fresh seafood flavors.'),
      item('Crab Meat Corn Soup', 338.80, 'Soup', Colors.yellow, customImagePath: 'assets/images/CMCSoup.jpg', description: 'Sweet corn soup elevated with real crab meat.'),
    ]);

    // Seafood
    menu['Seafood']!.addAll([
      item('Salt & Pepper Squid', 373.80, 'Seafood', Colors.purple, customImagePath: 'assets/images/SPS.jpg', description: 'Crispy fried squid tossed in a savory salt and pepper mix.'),
      item('Broccoli Flower with Squid', 373.80, 'Seafood', Colors.purple, customImagePath: 'assets/images/BFwSquid.jpg', description: 'Tender squid slices sautéed with fresh broccoli flowers.'),
      item('Broccoli Flower with Shrimp', 373.80, 'Seafood', Colors.lightBlue, customImagePath: 'assets/images/BFShrimp.jpg', description: 'Juicy shrimps paired with crunchy broccoli in a light sauce.'),
      item('Steamed Fish Fillet with Oyster Sauce', 423.80, 'Seafood', Colors.lightBlue, customImagePath: 'assets/images/SFFwOS.jpg', description: 'Delicate fish fillets steamed to perfection with oyster sauce.'),
      item('Fish Fillet with Salt & Pepper', 413.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/FFilletSA.jpg', description: 'Golden-fried fish fillets seasoned with salt and pepper.'),
      item('Sweet and Sour Fish Fillet', 403.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/SSFF.jpg', description: 'Crispy fish fillets in our signature sweet and sour glaze.'),
      item('Fish Fillet with Tausi Sauce', 413.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/FFwTS.jpg', description: 'Sautéed fish fillets with fermented black beans for a deep flavor.'),
      item('Fish Fillet with Broccoli Flower', 373.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/FFwBF.jpg', description: 'Classic combination of fish fillet and broccoli in a clear sauce.'),
      item('Fish Fillet with Sweet Corn', 393.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/FFwSC.jpg', description: 'Mild and sweet dish featuring fish fillets and creamy corn.'),
      item('Hot Shrimp Salad', 533.80, 'Seafood', Colors.lightGreen, customImagePath: 'assets/images/HSSalad.jpg', description: 'A unique combination of crispy shrimp and sweet fruit salad.'),
      item('Camaron Rebusado', 433.80, 'Seafood', Colors.lightGreen, customImagePath: 'assets/images/CamaronRebusado.jpg', description: 'Traditional Filipino-Chinese deep-fried battered shrimp.'),
      item('Shrimp with Scramble Egg', 353.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/SwSE.jpg', description: 'Fluffy scrambled eggs with tender, juicy shrimps.'),
    ]);

    // Roast and Soy Specialties
    menu['Roast and Soy Specialties']!.addAll([
      item('Lechon Macau', 675.80, 'Roast and Soy Specialties', Colors.brown, customImagePath: 'assets/images/LechonMacau.jpg', description: 'Crispy, golden-brown pork belly served with a traditional dipping sauce.'),
      item('Roast Pork Asado', 675.80, 'Roast and Soy Specialties', Colors.pink, customImagePath: 'assets/images/RPAsado.jpg', description: 'Sweet and savory Chinese-style roasted pork asado.'),
      item('Roast Chicken', 698.80, 'Roast and Soy Specialties', Colors.amber, customImagePath: 'assets/images/RoastChicken.jpg', description: 'Perfectly roasted chicken with crispy skin and juicy meat.'),
      item('Cold Cuts 3 Kinds', 408.80, 'Roast and Soy Specialties', Colors.amber, customImagePath: 'assets/images/CC3.png', description: 'An appetizer platter featuring three of our best roast specialties.'),
      item('Cold Cut 5 Kinds', 588.80, 'Roast and Soy Specialties', Colors.amber, customImagePath: 'assets/images/CC5.png', description: 'The ultimate appetizer platter with five varieties of meats.'),
      item('Soyed Taufo', 268.80, 'Roast and Soy Specialties', Colors.amber, customImagePath: 'assets/images/SoyedTaufo.png', description: 'Deep-fried tofu cubes simmered in a savory soy-based sauce.'),
    ]);

    // Pork
    menu['Pork']!.addAll([
      item('Sweet and Sour Pork', 393.80, 'Pork', Colors.red, customImagePath: 'assets/images/SSP.jpg', description: 'Classic Cantonese-style pork with a perfect balance of tangy and sweet flavors.'),
      item('Spareribs with OK Sauce', 423.80, 'Pork', Colors.black87, customImagePath: 'assets/images/SOkSauce.jpg', description: 'Tender spareribs glazed in our special savory OK sauce.'),
      item('Lumpiang Shanghai', 333.80, 'Pork', Colors.green, customImagePath: 'assets/images/LumpiangShanghai.jpg', description: 'Golden-fried pork spring rolls, a party favorite.'),
      item('Patatim with Cuapao', 843.80, 'Pork', Colors.brown, customImagePath: 'assets/images/PatatimCuapao.jpg', description: 'Slow-cooked pork leg in a sweet-savory sauce served with soft buns.'),
      item('Spareribs Ampalaya with Tausi', 413.80, 'Pork', Colors.black87, customImagePath: 'assets/images/SAwT.png', description: 'Spareribs sautéed with bitter melon and black bean sauce.'),
      item('Spareribs with Salt and Pepper', 423.80, 'Pork', Colors.red, customImagePath: 'assets/images/SwSP.jpg', description: 'Crispy fried spareribs seasoned with spicy salt and pepper.'),
      item('Minced Pork with Lettuce', 413.80, 'Pork', Colors.orange, customImagePath: 'assets/images/MPwL.jpg', description: 'Savory minced pork wrap served with fresh lettuce cups.'),
      item('Kangkong with Lechon Macau', 413.80, 'Pork', Colors.red, customImagePath: 'assets/images/KwLM.jpg', description: 'Stir-fried water spinach topped with crispy Lechon Macau.'),
    ]);

    // Noodles
    menu['Noodles']!.addAll([
      item('Pancit Canton', 398.80, 'Noodles', Colors.orange, customImagePath: 'assets/images/PancitCLM.jpg', description: 'Traditional stir-fried noodles tossed with fresh vegetables and savory meats.'),
      item('Seafood Canton', 388.80, 'Noodles', Colors.purple, customImagePath: 'assets/images/SeafoodCanton.jpg', description: 'Our classic Pancit Canton loaded with fresh seafood.'),
      item('Sliced Beef Hofan', 298.80, 'Noodles', Colors.green, customImagePath: 'assets/images/SBHofan.jpg', description: 'Stir-fried flat rice noodles with tender beef slices.'),
      item('Bihon Guisado', 358.80, 'Noodles', Colors.yellow, customImagePath: 'assets/images/BihonGuisado.jpg', description: 'Savory stir-fried thin rice noodles with mixed ingredients.'),
      item('Birthday Noodles', 378.80, 'Noodles', Colors.pink, customImagePath: 'assets/images/BirthdayNoodles.png', description: 'A celebratory noodle dish symbolizing long life and prosperity.'),
      item('Crispy Noodle Mixed Meat', 458.80, 'Noodles', Colors.yellow, customImagePath: 'assets/images/CNoodleMM.jpg', description: 'Crunchy deep-fried noodles topped with a rich meat gravy.'),
      item('Crispy Noodle Mixed Seafood', 458.80, 'Noodles', Colors.yellow, customImagePath: 'assets/images/CNMS.png', description: 'Crunchy deep-fried noodles topped with a savory seafood sauce.'),
      item('Bihon and Canton Mixed Guisado', 458.80, 'Noodles', Colors.red, customImagePath: 'assets/images/BCMG.jpg', description: 'A perfect combination of thin and thick noodles.'),
      item('Pancit Canton with Lechon Macau', 458.80, 'Noodles', Colors.red, customImagePath: 'assets/images/PancitCLM.jpg', description: 'Our signature Canton noodles topped with crispy pork belly.'),
    ]);

    // Mami or Noodles
    menu['Mami or Noodles']!.addAll([
      item('Roast Pork Asado Noodles', 238.80, 'Mami or Noodles', Colors.brown, customImagePath: 'assets/images/RPAN.png', description: 'Comforting noodle soup with our sweet roast pork asado.'),
      item('Beef Brisket Noodles', 338.80, 'Mami or Noodles', Colors.red, customImagePath: 'assets/images/BBNoodles.png', description: 'Rich beef broth with tender, slow-cooked beef brisket.'),
      item('Wanton Noodles', 338.80, 'Mami or Noodles', Colors.brown, customImagePath: 'assets/images/WantonNoodles.jpg', description: 'Traditional noodle soup with handmade pork dumplings.'),
      item('Beef Brisket & Wonton Noodles', 278.80, 'Mami or Noodles', Colors.purple, customImagePath: 'assets/images/BBWantonN.jpg', description: 'The best of both: beef brisket and wontons in one bowl.'),
      item('Wanton Soup (6pcs)', 268.80, 'Mami or Noodles', Colors.orange, customImagePath: 'assets/images/WantonSoup.png', description: 'Six pieces of our signature wontons in a clear, savory broth.'),
      item('Fishball Noodles', 248.80, 'Mami or Noodles', Colors.blue, customImagePath: 'assets/images/FishballNoodles.png', description: 'Noodle soup with bouncy, flavorful fish balls.'),
      item('Squidball Noodles', 248.80, 'Mami or Noodles', Colors.blue, customImagePath: 'assets/images/SquidballNoodles.png', description: 'Noodle soup with tasty squid balls.'),
      item('Lobsterball Noodles', 278.80, 'Mami or Noodles', Colors.blue, customImagePath: 'assets/images/LobsterballNoodles.png', description: 'Premium noodle soup with lobster-flavored balls.'),
    ]);

    // Hot Pot Specialties
    menu['Hot Pot Specialties']!.addAll([
      item('Minced Pork with Eggplant in Hot Pot', 343.80, 'Hot Pot Specialties', Colors.purple, customImagePath: 'assets/images/MPEHotPot.png', description: 'Savory minced pork and tender eggplant served sizzling in a hot pot.'),
      item('Fish Fillet with Taufo in Hot Pot', 403.80, 'Hot Pot Specialties', Colors.green, customImagePath: 'assets/images/FFTHotPot.jpg', description: 'Healthy fish fillets and tofu cubes in a flavorful broth.'),
      item('Lechon Kawali in Hot Pot', 413.80, 'Hot Pot Specialties', Colors.orange, customImagePath: 'assets/images/LKHotPot.png', description: 'Crispy pork pieces in a rich sauce, served in a traditional hot pot.'),
      item('Seafood Taufo in Hot Pot', 403.80, 'Hot Pot Specialties', Colors.deepOrange, customImagePath: 'assets/images/STHotPot.jpg', description: 'Assorted seafood and tofu simmered to perfection.'),
      item('Beef Brisket with Raddish in Hot Pot', 403.80, 'Hot Pot Specialties', Colors.red, customImagePath: 'assets/images/BBRHotPot.jpg', description: 'Hearty beef brisket and radish slow-cooked in a savory sauce.'),
      item('Roast Pork Asado with Taufo in Hot Pot', 413.80, 'Hot Pot Specialties', Colors.purple, customImagePath: 'assets/images/RPAwTHotPot.png', description: 'Sweet roast pork and tofu cubes in a delicious hot pot sauce.'),
    ]);

    // Fried Rice or Rice
    menu['Fried Rice or Rice']!.addAll([
      item('Yang Chow Fried Rice', 338.80, 'Fried Rice or Rice', Colors.red, customImagePath: 'assets/images/YCFriedRice.jpg', description: 'Our world-famous fried rice with shrimp, roast pork, and premium seasonings.'),
      item('Beef Fried Rice', 338.80, 'Fried Rice or Rice', Colors.orange, customImagePath: 'assets/images/BeefFriedRice.png', description: 'Savory fried rice loaded with tender beef bits.'),
      item('Chicken with Salted Fish (Fried Rice)', 338.80, 'Fried Rice or Rice', Colors.white70, customImagePath: 'assets/images/CSFFriedRice.jpg', description: 'Fragrant fried rice with chicken and the unique salty kick of salted fish.'),
      item('Garlic Fried Rice', 235.80, 'Fried Rice or Rice', Colors.deepOrange, customImagePath: 'assets/images/GarlicFriedRice.jpg', description: 'Simple, aromatic rice tossed with golden toasted garlic.'),
      item('Pineapple Fried Rice', 388.80, 'Fried Rice or Rice', Colors.yellow, customImagePath: 'assets/images/PineappleFriedRice.jpg', description: 'A tropical twist on fried rice with sweet pineapple and savory meats.'),
      item('Steamed Rice (Platter)', 225.80, 'Fried Rice or Rice', Colors.yellow, customImagePath: 'assets/images/SteamedRiceP.jpg', description: 'A large platter of perfectly steamed white rice.'),
      item('Steamed Rice (1 Cup)', 68.80, 'Fried Rice or Rice', Colors.yellow, customImagePath: 'assets/images/SteamedRiceC.jpg', description: 'A single serving of fluffy steamed white rice.'),
    ]);

    // Dimsum
    menu['Dimsum']!.addAll([
      item('Siomai with Shrimp', 143.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/SwS.jpg', description: 'Succulent shrimp and pork dumplings steamed to perfection.'),
      item('Quail Egg Siomai', 143.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/QESiomai.png', description: 'Our signature siomai with a whole quail egg inside.'),
      item('Wanton Dumplings', 143.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/WantonDumplings.jpg', description: 'Classic steamed pork dumplings with a savory filling.'),
      item('Shark\'s Fin Dumpling', 143.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/SFDumpling.png', description: 'A premium dumpling choice with a rich, savory seafood filling.'),
      item('Asado Siopao', 143.80, 'Dimsum', Colors.purple, customImagePath: 'assets/images/AsadoSiopao.png', description: 'Soft steamed bun filled with sweet and savory roast pork asado.'),
      item('Bola-Bola Siopao', 143.80, 'Dimsum', Colors.lightBlue, customImagePath: 'assets/images/BBSiopao.jpg', description: 'Soft steamed bun with a flavorful meatball and egg filling.'),
      item('Tausi Spareribs', 138.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/TausiSpareribs.jpg', description: 'Tender pork spareribs steamed with fermented black bean sauce.'),
      item('Cuapao / Mantau', 98.80, 'Dimsum', Colors.amber, customImagePath: 'assets/images/CuapaoMantau.jpg', description: 'Simple, soft steamed buns perfect for pairing with savory dishes.'),
      item('Chicken Feet', 143.80, 'Dimsum', Colors.red, customImagePath: 'assets/images/ChickenFeet.jpg', description: 'Tender chicken feet braised in a rich, spicy-sweet sauce.'),
      item('Hakaw', 165.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/Hakaw.png', description: 'Translucent dumplings filled with plump, juicy shrimps.'),
      item('Spinach Dumpling', 165.80, 'Dimsum', Colors.brown, customImagePath: 'assets/images/SpinachDumpling.jpg', description: 'Healthy and flavorful dumplings with a spinach-infused filling.'),
      item('Special Siopao', 165.80, 'Dimsum', Colors.purple, customImagePath: 'assets/images/SpecialSiopao.png', description: 'Our extra-large siopao with a premium mixed filling.'),
    ]);

    // Congee
    menu['Congee']!.addAll([
      item('Pork Century Egg Congee', 205.80, 'Congee', Colors.grey, customImagePath: 'assets/images/PCEC.png', description: 'Hearty rice porridge with lean pork and flavorful century egg.'),
      item('Pork Liver Congee', 205.80, 'Congee', Colors.grey, customImagePath: 'assets/images/PLCongee.jpg', description: 'Nutritious rice porridge featuring tender pork liver.'),
      item('Seafood Congee', 235.80, 'Congee', Colors.grey, customImagePath: 'assets/images/SeafoodCongee.png', description: 'Heartwarming porridge loaded with a variety of fresh seafood.'),
      item('Sliced Fish Congee', 225.80, 'Congee', Colors.grey, customImagePath: 'assets/images/SFCongee.jpg', description: 'Light and healthy rice porridge with delicate fish slices.'),
      item('Beef Balls Congee', 235.80, 'Congee', Colors.deepOrange, customImagePath: 'assets/images/BBCongee.jpg', description: 'Rice porridge served with tasty, handmade beef balls.'),
      item('Sliced Chicken Congee', 204.80, 'Congee', Colors.deepOrange, customImagePath: 'assets/images/SCC.png', description: 'Comforting rice porridge with tender chicken strips.'),
      item('Century Egg', 78.80, 'Congee', Colors.grey, customImagePath: 'assets/images/CenturyEgg.jpg', description: 'A side serving of the classic Chinese preserved egg.'),
      item('Fresh Egg', 48.80, 'Congee', Colors.yellow, customImagePath: 'assets/images/FreshEgg.jpg', description: 'Add a fresh egg to your congee for extra creaminess.'),
    ]);

    // Chicken
    menu['Chicken']!.addAll([
      item('Buttered Chicken', 358.80, 'Chicken', Colors.amber, customImagePath: 'assets/images/ButteredChicken.jpg', description: 'Crispy fried chicken pieces coated in a rich, velvety butter sauce.'),
      item('Yang Chow Fried Chicken', 678.80, 'Chicken', Colors.orange, customImagePath: 'assets/images/YCFChicken.jpg', description: 'Our signature crispy fried chicken, seasoned the Yang Chow way.'),
      item('Sweet and Sour Chicken', 378.80, 'Chicken', Colors.orange, customImagePath: 'assets/images/SSChicken.jpg', description: 'Crispy chicken pieces tossed in our classic sweet and sour sauce.'),
      item('Fried Chicken with Salted Egg Yolk', 378.80, 'Chicken', Colors.orange, customImagePath: 'assets/images/FCwSEY.jpg', description: 'Trendy and delicious chicken coated in rich salted egg yolk sauce.'),
      item('Lemon Chicken', 378.80, 'Chicken', Colors.yellow, customImagePath: 'assets/images/LemonChicken.jpg', description: 'Zesty and sweet fried chicken with a refreshing lemon glaze.'),
      item('Sliced Chicken with Cashew Nuts and Quail Egg', 398.80, 'Chicken', Colors.brown, customImagePath: 'assets/images/SCwCNQE.jpg', description: 'A deluxe chicken stir-fry with crunchy cashews and quail eggs.'),
    ]);

    // Beef
    menu['Beef']!.addAll([
      item('Beef with Broccoli Leaves (Kaylan)', 420.80, 'Beef', Colors.brown, customImagePath: 'assets/images/BeefBLK.jpg', description: 'Tender beef slices with vibrant broccoli leaves in a savory sauce.'),
      item('Beef with Broccoli Flower', 420.80, 'Beef', Colors.red, customImagePath: 'assets/images/BeefBF.jpg', description: 'Classic beef and broccoli stir-fry with a rich soy glaze.'),
      item('Beef with Ampalaya', 438.80, 'Beef', Colors.brown, customImagePath: 'assets/images/BAmpalaya.jpg', description: 'Savory beef slices sautéed with healthy bitter melon.'),
      item('Beef Steak Chinese Style', 438.80, 'Beef', Colors.red, customImagePath: 'assets/images/BSCS.jpg', description: 'Tenderized beef steak cooked with a sweet-savory Chinese sauce.'),
      item('Beef with Black Pepper', 438.80, 'Beef', Colors.green, customImagePath: 'assets/images/BeefBP.png', description: 'Aromatic beef stir-fry with a bold black pepper kick.'),
      item('Beef with Green Pepper', 438.80, 'Beef', Colors.green, customImagePath: 'assets/images/BeefGP.png', description: 'Savory beef slices sautéed with fresh green bell peppers.'),
      item('Beef with Scramble Egg', 338.80, 'Beef', Colors.red, customImagePath: 'assets/images/BSE.jpeg', description: 'Home-style scrambled eggs with tender, seasoned beef.'),
      item('Slice Beef Mango', 438.80, 'Beef', Colors.green, customImagePath: 'assets/images/SBM.jpg', description: 'A unique and fruity beef dish with sweet mango slices.'),
    ]);

    // Appetizer
    menu['Appetizer']!.addAll([
      item('Jelly Fish with Century Egg', 278.80, 'Appetizer', Colors.orange, customImagePath: 'assets/images/JellyFCE.jpg', description: 'A traditional Chinese appetizer featuring chilled jelly fish and century egg.'),
      item('Jelly Fish', 198.80, 'Appetizer', Colors.pink, customImagePath: 'assets/images/JellyFish.jpg', description: 'Chilled jelly fish seasoned with sesame oil and spices.'),
      item('Calamares', 298.80, 'Appetizer', Colors.deepOrange, customImagePath: 'assets/images/Calamares.jpg', description: 'Deep-fried battered squid rings served with a dipping sauce.'),
    ]);

    return menu;
  }

  static int getTotalMenuItemsCount() {
    final menu = getMenu();
    return menu.values.fold(0, (sum, list) => sum + list.length);
  }
}
