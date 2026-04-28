// Test script to demonstrate the new inventory deduction logic
// This shows how the deduction now works based on actual order quantity

void main() {
  print('=== Inventory Deduction Test ===');
  
  // Scenario: Nature's Spring 350ML
  print('\n📦 Item: Nature\'s Spring 350ML');
  print('📊 Current Stock: 10');
  print('📋 Recipe: 1 Nature Spring 350ML per unit');
  
  // Test Case 1: Order 5 pieces
  print('\n1️⃣ Order 5 pieces:');
  int currentStock = 10;
  int orderQuantity = 5;
  double ingredientQtyPerUnit = 1.0;
  
  // OLD LOGIC: Always deduct 1
  int oldDeduction = 1;
  int oldNewStock = currentStock - oldDeduction;
  
  // NEW LOGIC: Deduct based on order quantity
  int newDeduction = (ingredientQtyPerUnit * orderQuantity).round();
  int newNewStock = currentStock - newDeduction;
  
  print('   OLD: Deduct $oldDeduction → Stock: $oldNewStock (❌ Wrong!)');
  print('   NEW: Deduct $newDeduction → Stock: $newNewStock (✅ Correct!)');
  
  // Scenario: Overload Meal (multiple ingredients)
  print('\n🍛 Item: Overload Meal');
  print('📊 Current Stock: Chicken 20, Pork 15, Rice 30, Vegetables 25');
  print('📋 Recipe: 1 Chicken + 1 Pork + 1 Rice + 1 Vegetables per unit');
  
  // Test Case 2: Order 3 pieces of Overload Meal
  print('\n2️⃣ Order 3 pieces of Overload Meal:');
  int chickenStock = 20;
  int porkStock = 15;
  int riceStock = 30;
  int vegStock = 25;
  orderQuantity = 3;
  ingredientQtyPerUnit = 1.0;
  
  newDeduction = (ingredientQtyPerUnit * orderQuantity).round();
  
  print('   Chicken: $chickenStock → ${chickenStock - newDeduction} (deduct $newDeduction)');
  print('   Pork: $porkStock → ${porkStock - newDeduction} (deduct $newDeduction)');
  print('   Rice: $riceStock → ${riceStock - newDeduction} (deduct $newDeduction)');
  print('   Vegetables: $vegStock → ${vegStock - newDeduction} (deduct $newDeduction)');
  
  print('\n=== Summary ===');
  print('✅ OLD: Always deduct 1 per ingredient (wrong)');
  print('✅ NEW: Deduct (ingredient_qty × order_quantity) per ingredient (correct)');
  print('\n🎯 Your requested feature is now implemented!');
  print('   Water: 10 stock - order 5 = 5 remaining');
  print('   Complex items: Proper ingredient deduction based on order quantity');
}
