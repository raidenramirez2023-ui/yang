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
    'Drinks',
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
    'Drinks': [
      'assets/images/NatureSpring.jpg',
      'assets/images/Lipton.jpg',
      'assets/images/7UPCan.jpg',
      'assets/images/PepsiRegBottle.jpg',
      'assets/images/PepsiMaxCan.jpg',
      'assets/images/MirindaCan.jpg',
      'assets/images/MountainDCan.jpg',
      'assets/images/MugRBCan.jpg',
      'assets/images/SanMigLBot.jpg',
      'assets/images/7UPliter.jpg',
      'assets/images/Mirindaliter.jpg',
      'assets/images/MountainDliter.jpg',
      'assets/images/PepsiRegliter.jpg',
      'assets/images/PepsiMaxliter.jpg',
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

    MenuItem item(String name, double price, String category, Color color, {String? customImagePath}) {
      return MenuItem(
        name: name,
        price: price,
        category: category,
        fallbackImagePath: customImagePath ?? nextImage(category),
        color: color,
        customImagePath: customImagePath,
      );
    }

    // --- Data Extraction from shared_pos_widget.dart ---
    
    // Yangchow Family Bundles
    menu['Yangchow Family Bundles']!.addAll([
      item('YangChow 1', 1880.80, 'Yangchow Family Bundles', Colors.orange, customImagePath: 'assets/images/YC1.png'),
      item('YangChow 2', 1880.80, 'Yangchow Family Bundles', Colors.deepOrange, customImagePath: 'assets/images/YC2.png'),
      item('YangChow 3', 3588.80, 'Yangchow Family Bundles', Colors.deepOrange, customImagePath: 'assets/images/YC3.jpg'),
      item('YangChow 4', 4588.80, 'Yangchow Family Bundles', Colors.deepOrange, customImagePath: 'assets/images/YC4.jpg'),
      item('Overload Meal', 298.80, 'Yangchow Family Bundles', Colors.deepOrange, customImagePath: 'assets/images/Overloadmeals.png'),
    ]);

    // Vegetables
    menu['Vegetables']!.addAll([
      item('Broccoli Leaves with Oyster Sauce', 278.80, 'Vegetables', Colors.blue, customImagePath: 'assets/images/VBLwOS.jpg'),
      item('Broccoli Flower with Oyster Sauce', 368.80, 'Vegetables', Colors.orange, customImagePath: 'assets/images/BFOyster.png'),
      item('Taiwan Pechay with Oyster Sauce', 288.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/TPOyster.png'),
      item('Spinach/Polanchay Stir Fried', 298.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/SPSF.jpg'),
      item('Braised Sea Cucumber with Broccoli Flower', 328.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/VBSCwBF.jpg'),
      item('Lohanchay', 298.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/Lohanchay.png'),
      item('Chopsuey Guisado', 338.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/ChopsueyGuisado.jpg'),
      item('Chinese Kangkong with Garlic', 238.80, 'Vegetables', Colors.green, customImagePath: 'assets/images/VCKwG.jpg'),
    ]);

    // Special Noodles
    menu['Special Noodles']!.addAll([
      item('YC Special Noodles', 298.80, 'Special Noodles', Colors.amber, customImagePath: 'assets/images/YCSNoodles.png'),
    ]);

    // Soup
    menu['Soup']!.addAll([
      item('Chicken Corn Soup', 308.80, 'Soup', Colors.yellow, customImagePath: 'assets/images/CCSoup.jpg'),
      item('Hot & Sour Soup', 338.80, 'Soup', Colors.red, customImagePath: 'assets/images/HSSoup.jpg'),
      item('Hototay Soup', 338.80, 'Soup', Colors.purple, customImagePath: 'assets/images/HototaySoup.jpg'),
      item('Minced Beef with Egg White Soup', 308.80, 'Soup', Colors.purple, customImagePath: 'assets/images/MBwEWSoup.png'),
      item('Nido Soup with Quail Egg', 328.80, 'Soup', Colors.brown, customImagePath: 'assets/images/NSoupQE.png'),
      item('Spinach Seafood Soup', 338.80, 'Soup', Colors.purple, customImagePath: 'assets/images/SSSoup.jpg'),
      item('Crab Meat Corn Soup', 338.80, 'Soup', Colors.yellow, customImagePath: 'assets/images/CMCSoup.jpg'),
    ]);

    // Seafood
    menu['Seafood']!.addAll([
      item('Salt & Pepper Squid', 373.80, 'Seafood', Colors.purple, customImagePath: 'assets/images/SPS.jpg'),
      item('Broccoli Flower with Squid', 373.80, 'Seafood', Colors.purple, customImagePath: 'assets/images/BFwSquid.jpg'),
      item('Broccoli Flower with Shrimp', 373.80, 'Seafood', Colors.lightBlue, customImagePath: 'assets/images/BFShrimp.jpg'),
      item('Steamed Fish Fillet with Oyster Sauce', 423.80, 'Seafood', Colors.lightBlue, customImagePath: 'assets/images/SFFwOS.jpg'),
      item('Fish Fillet with Salt & Pepper', 413.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/FFilletSA.jpg'),
      item('Sweet and Sour Fish Fillet', 403.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/SSFF.jpg'),
      item('Fish Fillet with Tausi Sauce', 413.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/FFwTS.jpg'),
      item('Fish Fillet with Broccoli Flower', 373.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/FFwBF.jpg'),
      item('Fish Fillet with Sweet Corn', 393.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/FFwSC.jpg'),
      item('Hot Shrimp Salad', 533.80, 'Seafood', Colors.lightGreen, customImagePath: 'assets/images/HSSalad.jpg'),
      item('Camaron Rebusado', 433.80, 'Seafood', Colors.lightGreen, customImagePath: 'assets/images/CamaronRebusado.jpg'),
      item('Shrimp with Scramble Egg', 353.80, 'Seafood', Colors.cyan, customImagePath: 'assets/images/SwSE.jpg'),
    ]);

    // Roast and Soy Specialties
    menu['Roast and Soy Specialties']!.addAll([
      item('Lechon Macau', 675.80, 'Roast and Soy Specialties', Colors.brown, customImagePath: 'assets/images/LechonMacau.jpg'),
      item('Roast Pork Asado', 675.80, 'Roast and Soy Specialties', Colors.pink, customImagePath: 'assets/images/RPAsado.jpg'),
      item('Roast Chicken', 698.80, 'Roast and Soy Specialties', Colors.amber, customImagePath: 'assets/images/RoastChicken.jpg'),
      item('Cold Cuts 3 Kinds', 408.80, 'Roast and Soy Specialties', Colors.amber, customImagePath: 'assets/images/CC3.png'),
      item('Cold Cut 5 Kinds', 588.80, 'Roast and Soy Specialties', Colors.amber, customImagePath: 'assets/images/CC5.png'),
      item('Soyed Taufo', 268.80, 'Roast and Soy Specialties', Colors.amber, customImagePath: 'assets/images/SoyedTaufo.png'),
    ]);

    // Pork
    menu['Pork']!.addAll([
      item('Sweet and Sour Pork', 393.80, 'Pork', Colors.red, customImagePath: 'assets/images/SSP.jpg'),
      item('Spareribs with OK Sauce', 423.80, 'Pork', Colors.black87, customImagePath: 'assets/images/SOkSauce.jpg'),
      item('Lumpiang Shanghai', 333.80, 'Pork', Colors.green, customImagePath: 'assets/images/LumpiangShanghai.jpg'),
      item('Patatim with Cuapao', 843.80, 'Pork', Colors.brown, customImagePath: 'assets/images/PatatimCuapao.jpg'),
      item('Spareribs Ampalaya with Tausi', 413.80, 'Pork', Colors.black87, customImagePath: 'assets/images/SAwT.png'),
      item('Spareribs with Salt and Pepper', 423.80, 'Pork', Colors.red, customImagePath: 'assets/images/SwSP.jpg'),
      item('Minced Pork with Lettuce', 413.80, 'Pork', Colors.orange, customImagePath: 'assets/images/MPwL.jpg'),
      item('Kangkong with Lechon Macau', 413.80, 'Pork', Colors.red, customImagePath: 'assets/images/KwLM.jpg'),
    ]);

    // Noodles
    menu['Noodles']!.addAll([
      item('Pancit Canton', 398.80, 'Noodles', Colors.orange, customImagePath: 'assets/images/PancitCLM.jpg'),
      item('Seafood Canton', 388.80, 'Noodles', Colors.purple, customImagePath: 'assets/images/SeafoodCanton.jpg'),
      item('Sliced Beef Hofan', 298.80, 'Noodles', Colors.green, customImagePath: 'assets/images/SBHofan.jpg'),
      item('Bihon Guisado', 358.80, 'Noodles', Colors.yellow, customImagePath: 'assets/images/BihonGuisado.jpg'),
      item('Birthday Noodles', 378.80, 'Noodles', Colors.pink, customImagePath: 'assets/images/BirthdayNoodles.png'),
      item('Crispy Noodle Mixed Meat', 458.80, 'Noodles', Colors.yellow, customImagePath: 'assets/images/CNoodleMM.jpg'),
      item('Crispy Noodle Mixed Seafood', 458.80, 'Noodles', Colors.yellow, customImagePath: 'assets/images/CNMS.png'),
      item('Bihon and Canton Mixed Guisado', 458.80, 'Noodles', Colors.red, customImagePath: 'assets/images/BCMG.jpg'),
      item('Pancit Canton with Lechon Macau', 458.80, 'Noodles', Colors.red, customImagePath: 'assets/images/PancitCLM.jpg'),
    ]);

    // Mami or Noodles
    menu['Mami or Noodles']!.addAll([
      item('Roast Pork Asado Noodles', 238.80, 'Mami or Noodles', Colors.brown, customImagePath: 'assets/images/RPAN.png'),
      item('Beef Brisket Noodles', 338.80, 'Mami or Noodles', Colors.red, customImagePath: 'assets/images/BBNoodles.png'),
      item('Wanton Noodles', 338.80, 'Mami or Noodles', Colors.brown, customImagePath: 'assets/images/WantonNoodles.jpg'),
      item('Beef Brisket & Wonton Noodles', 278.80, 'Mami or Noodles', Colors.purple, customImagePath: 'assets/images/BBWantonN.jpg'),
      item('Wanton Soup (6pcs)', 268.80, 'Mami or Noodles', Colors.orange, customImagePath: 'assets/images/WantonSoup.png'),
      item('Fishball Noodles', 248.80, 'Mami or Noodles', Colors.blue, customImagePath: 'assets/images/FishballNoodles.png'),
      item('Squidball Noodles', 248.80, 'Mami or Noodles', Colors.blue, customImagePath: 'assets/images/SquidballNoodles.png'),
      item('Lobsterball Noodles', 278.80, 'Mami or Noodles', Colors.blue, customImagePath: 'assets/images/LobsterballNoodles.png'),
    ]);

    // Hot Pot Specialties
    menu['Hot Pot Specialties']!.addAll([
      item('Minced Pork with Eggplant in Hot Pot', 343.80, 'Hot Pot Specialties', Colors.purple, customImagePath: 'assets/images/MPEHotPot.png'),
      item('Fish Fillet with Taufo in Hot Pot', 403.80, 'Hot Pot Specialties', Colors.green, customImagePath: 'assets/images/FFTHotPot.jpg'),
      item('Lechon Kawali in Hot Pot', 413.80, 'Hot Pot Specialties', Colors.orange, customImagePath: 'assets/images/LKHotPot.png'),
      item('Seafood Taufo in Hot Pot', 403.80, 'Hot Pot Specialties', Colors.deepOrange, customImagePath: 'assets/images/STHotPot.jpg'),
      item('Beef Brisket with Raddish in Hot Pot', 403.80, 'Hot Pot Specialties', Colors.red, customImagePath: 'assets/images/BBRHotPot.jpg'),
      item('Roast Pork Asado with Taufo in Hot Pot', 413.80, 'Hot Pot Specialties', Colors.purple, customImagePath: 'assets/images/RPAwTHotPot.png'),
    ]);

    // Fried Rice or Rice
    menu['Fried Rice or Rice']!.addAll([
      item('Yang Chow Fried Rice', 338.80, 'Fried Rice or Rice', Colors.red, customImagePath: 'assets/images/YCFriedRice.jpg'),
      item('Beef Fried Rice', 338.80, 'Fried Rice or Rice', Colors.orange, customImagePath: 'assets/images/BeefFriedRice.png'),
      item('Chicken with Salted Fish (Fried Rice)', 338.80, 'Fried Rice or Rice', Colors.white70, customImagePath: 'assets/images/CSFFriedRice.jpg'),
      item('Garlic Fried Rice', 235.80, 'Fried Rice or Rice', Colors.deepOrange, customImagePath: 'assets/images/GarlicFriedRice.jpg'),
      item('Pineapple Fried Rice', 388.80, 'Fried Rice or Rice', Colors.yellow, customImagePath: 'assets/images/PineappleFriedRice.jpg'),
      item('Steamed Rice (Platter)', 225.80, 'Fried Rice or Rice', Colors.yellow, customImagePath: 'assets/images/SteamedRiceP.jpg'),
      item('Steamed Rice (1 Cup)', 68.80, 'Fried Rice or Rice', Colors.yellow, customImagePath: 'assets/images/SteamedRiceC.jpg'),
    ]);

    // Dimsum
    menu['Dimsum']!.addAll([
      item('Siomai with Shrimp', 143.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/SwS.jpg'),
      item('Quail Egg Siomai', 143.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/QESiomai.png'),
      item('Wanton Dumplings', 143.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/WantonDumplings.jpg'),
      item('Shark\'s Fin Dumpling', 143.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/SFDumpling.png'),
      item('Asado Siopao', 143.80, 'Dimsum', Colors.purple, customImagePath: 'assets/images/AsadoSiopao.png'),
      item('Bola-Bola Siopao', 143.80, 'Dimsum', Colors.lightBlue, customImagePath: 'assets/images/BBSiopao.jpg'),
      item('Tausi Spareribs', 138.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/TausiSpareribs.jpg'),
      item('Cuapao / Mantau', 98.80, 'Dimsum', Colors.amber, customImagePath: 'assets/images/CuapaoMantau.jpg'),
      item('Chicken Feet', 143.80, 'Dimsum', Colors.red, customImagePath: 'assets/images/ChickenFeet.jpg'),
      item('Hakaw', 165.80, 'Dimsum', Colors.orange, customImagePath: 'assets/images/Hakaw.png'),
      item('Spinach Dumpling', 165.80, 'Dimsum', Colors.brown, customImagePath: 'assets/images/SpinachDumpling.jpg'),
      item('Special Siopao', 165.80, 'Dimsum', Colors.purple, customImagePath: 'assets/images/SpecialSiopao.png'),
    ]);

    // Congee
    menu['Congee']!.addAll([
      item('Pork Century Egg Congee', 205.80, 'Congee', Colors.grey, customImagePath: 'assets/images/PCEC.png'),
      item('Pork Liver Congee', 205.80, 'Congee', Colors.grey, customImagePath: 'assets/images/PLCongee.jpg'),
      item('Seafood Congee', 235.80, 'Congee', Colors.grey, customImagePath: 'assets/images/SeafoodCongee.png'),
      item('Sliced Fish Congee', 225.80, 'Congee', Colors.grey, customImagePath: 'assets/images/SFCongee.jpg'),
      item('Beef Balls Congee', 235.80, 'Congee', Colors.deepOrange, customImagePath: 'assets/images/BBCongee.jpg'),
      item('Sliced Chicken Congee', 204.80, 'Congee', Colors.deepOrange, customImagePath: 'assets/images/SCC.png'),
      item('Century Egg', 78.80, 'Congee', Colors.grey, customImagePath: 'assets/images/CenturyEgg.jpg'),
      item('Fresh Egg', 48.80, 'Congee', Colors.yellow, customImagePath: 'assets/images/FreshEgg.jpg'),
    ]);

    // Chicken
    menu['Chicken']!.addAll([
      item('Buttered Chicken', 358.80, 'Chicken', Colors.amber, customImagePath: 'assets/images/ButteredChicken.jpg'),
      item('Yang Chow Fried Chicken', 678.80, 'Chicken', Colors.orange, customImagePath: 'assets/images/YCFChicken.jpg'),
      item('Sweet and Sour Chicken', 378.80, 'Chicken', Colors.orange, customImagePath: 'assets/images/SSChicken.jpg'),
      item('Fried Chicken with Salted Egg Yolk', 378.80, 'Chicken', Colors.orange, customImagePath: 'assets/images/FCwSEY.jpg'),
      item('Lemon Chicken', 378.80, 'Chicken', Colors.yellow, customImagePath: 'assets/images/LemonChicken.jpg'),
      item('Sliced Chicken with Cashew Nuts and Quail Egg', 398.80, 'Chicken', Colors.brown, customImagePath: 'assets/images/SCwCNQE.jpg'),
    ]);

    // Beef
    menu['Beef']!.addAll([
      item('Beef with Broccoli Leaves (Kaylan)', 420.80, 'Beef', Colors.brown, customImagePath: 'assets/images/BeefBLK.jpg'),
      item('Beef with Broccoli Flower', 420.80, 'Beef', Colors.red, customImagePath: 'assets/images/BeefBF.jpg'),
      item('Beef with Ampalaya', 438.80, 'Beef', Colors.brown, customImagePath: 'assets/images/BAmpalaya.jpg'),
      item('Beef Steak Chinese Style', 438.80, 'Beef', Colors.red, customImagePath: 'assets/images/BSCS.jpg'),
      item('Beef with Black Pepper', 438.80, 'Beef', Colors.green, customImagePath: 'assets/images/BeefBP.png'),
      item('Beef with Green Pepper', 438.80, 'Beef', Colors.green, customImagePath: 'assets/images/BeefGP.png'),
      item('Beef with Scramble Egg', 338.80, 'Beef', Colors.red, customImagePath: 'assets/images/BSE.jpeg'),
      item('Slice Beef Mango', 438.80, 'Beef', Colors.green, customImagePath: 'assets/images/SBM.jpg'),
    ]);

    // Appetizer
    menu['Appetizer']!.addAll([
      item('Jelly Fish with Century Egg', 278.80, 'Appetizer', Colors.orange, customImagePath: 'assets/images/JellyFCE.jpg'),
      item('Jelly Fish', 198.80, 'Appetizer', Colors.pink, customImagePath: 'assets/images/JellyFish.jpg'),
      item('Calamares', 298.80, 'Appetizer', Colors.deepOrange, customImagePath: 'assets/images/Calamares.jpg'),
    ]);

    // Drinks
    menu['Drinks']!.addAll([
      item('Natures Spring 350ML', 20.80, 'Drinks', Colors.orange, customImagePath: 'assets/images/NatureSpring.jpg'),
      item('Lipton Iced Tea Lemon Can', 78.80, 'Drinks', Colors.pink, customImagePath: 'assets/images/Lipton.jpg'),
      item('7UP Can', 78.80, 'Drinks', Colors.deepOrange, customImagePath: 'assets/images/7UPCan.jpg'),
      item('Pepsi Regular Bottle', 78.80, 'Drinks', Colors.orange, customImagePath: 'assets/images/PepsiRegBottle.jpg'),
      item('Pepsi Max Can', 78.80, 'Drinks', Colors.pink, customImagePath: 'assets/images/PepsiMaxCan.jpg'),
      item('Mirinda Can', 78.80, 'Drinks', Colors.pink, customImagePath: 'assets/images/MirindaCan.jpg'),
      item('Mountain Dew Can', 78.80, 'Drinks', Colors.deepOrange, customImagePath: 'assets/images/MountainDCan.jpg'),
      item('Mug Root Beer Can', 78.80, 'Drinks', Colors.orange, customImagePath: 'assets/images/MugRBCan.jpg'),
      item('San Mig Light Bottle', 78.80, 'Drinks', Colors.deepOrange, customImagePath: 'assets/images/SanMigLBot.jpg'),
      item('7UP 1.5 Liter', 108.80, 'Drinks', Colors.orange, customImagePath: 'assets/images/7UPliter.jpg'),
      item('Mirinda 1.5 Liter', 108.80, 'Drinks', Colors.pink, customImagePath: 'assets/images/Mirindaliter.jpg'),
      item('Mountain Dew 1.5 Liter', 108.80, 'Drinks', Colors.deepOrange, customImagePath: 'assets/images/MountainDliter.jpg'),
      item('Pepsi Regular 1.5 Liter', 108.80, 'Drinks', Colors.orange, customImagePath: 'assets/images/PepsiRegliter.jpg'),
      item('Pepsi Max 1.5 Liter', 108.80, 'Drinks', Colors.pink, customImagePath: 'assets/images/PepsiMaxliter.jpg'),
    ]);

    return menu;
  }

  static int getTotalMenuItemsCount() {
    final menu = getMenu();
    return menu.values.fold(0, (sum, list) => sum + list.length);
  }
}
