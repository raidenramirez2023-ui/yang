import 'dart:io';

void main() async {
  final file = File('lib/services/menu_service.dart');
  final lines = await file.readAsLines();
  
  final List<String> newLines = [];
  bool skipMode = false;
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    
    if (line.contains('// --- Data Extraction from shared_pos_widget.dart ---')) {
      skipMode = true;
      newLines.add(line);
      newLines.add('    // Hardcoded menus have been removed. Items are now strictly fetched from Supabase.');
      continue;
    }
    
    if (skipMode && line.contains('return menu;')) {
      skipMode = false;
    }
    
    if (!skipMode) {
      newLines.add(line);
    }
  }
  
  await file.writeAsString(newLines.join('\n'));
  print('Menu cleaned!');
}
