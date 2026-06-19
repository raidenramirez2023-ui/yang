import 'dart:convert';
import 'package:flutter/services.dart';

class LocationService {
  static List<String> _lagunaMunicipalities = [];
  static bool _isLoaded = false;

  static Future<void> loadLocations() async {
    if (_isLoaded) return;

    try {
      final String jsonString = await rootBundle.loadString('assets/json/ph_locations.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      // Navigate to Region IV-A -> empty province (Laguna) -> municipality_list
      if (data.containsKey('4A')) {
        final region4A = data['4A'] as Map<String, dynamic>;
        if (region4A.containsKey('province_list')) {
          final provinceList = region4A['province_list'] as Map<String, dynamic>;
          
          // Laguna is stored under an empty string key
          if (provinceList.containsKey('')) {
            final laguna = provinceList[''] as Map<String, dynamic>;
            if (laguna.containsKey('municipality_list')) {
              final municipalityList = laguna['municipality_list'] as Map<String, dynamic>;
              
              _lagunaMunicipalities = municipalityList.keys.toList();
              _lagunaMunicipalities.sort(); // Sort alphabetically
              _isLoaded = true;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading locations: $e');
      _lagunaMunicipalities = [];
    }
  }

  static List<String> getLagunaMunicipalities() {
    return _lagunaMunicipalities;
  }

  static bool get isLoaded => _isLoaded;
}
