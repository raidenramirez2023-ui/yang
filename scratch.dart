import 'dart:io';

void main() async {
  final file = File('lib/services/recipe_service.dart');
  final lines = await file.readAsLines();
  
  int startIdx = -1;
  int endIdx = -1;
  
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('static const Map<String, Map<String, dynamic>> recipeDatabase = {')) {
      startIdx = i; // Line 11 (0-indexed)
    }
    if (startIdx != -1 && lines[i].contains('Future<Recipe?> getRecipeForMenuItem')) {
      // Find the closing brace just before this
      for (int j = i - 1; j > startIdx; j--) {
        if (lines[j].trim() == '};') {
          endIdx = j;
          break;
        }
      }
      break;
    }
  }
  
  if (startIdx != -1 && endIdx != -1) {
    lines.removeRange(startIdx, endIdx + 1);
    await file.writeAsString(lines.join('\n'));
    print('Successfully removed recipeDatabase');
  } else {
    print('Failed to find recipeDatabase boundaries: start=$startIdx, end=$endIdx');
  }
}
