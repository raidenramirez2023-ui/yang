import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class LocationSelector extends StatefulWidget {
  final String? selectedRegion;
  final String? selectedProvince;
  final String? selectedMunicipality;
  final String? selectedBarangay;
  final Function(String? region, String? province, String? municipality, String? barangay) onLocationChanged;

  const LocationSelector({
    super.key,
    this.selectedRegion,
    this.selectedProvince,
    this.selectedMunicipality,
    this.selectedBarangay,
    required this.onLocationChanged,
  });

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  Map<String, dynamic>? _locationData;
  List<String> _regions = [];
  List<String> _provinces = [];
  List<String> _municipalities = [];
  List<String> _barangays = [];

  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedMunicipality;
  String? _selectedBarangay;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedRegion = widget.selectedRegion;
    _selectedProvince = widget.selectedProvince;
    _selectedMunicipality = widget.selectedMunicipality;
    _selectedBarangay = widget.selectedBarangay;
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    try {
      final String jsonString = await rootBundle.loadString('json/ph_locations.json');
      print('DEBUG: Attempting to load asset from: json/ph_locations.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      
      setState(() {
        _locationData = data;
        _regions = data.keys.toList();
        _isLoading = false;
      });

      // If initial values are provided, populate dependent dropdowns
      if (_selectedRegion != null) {
        _updateProvinces(_selectedRegion!);
        if (_selectedProvince != null) {
          _updateMunicipalities(_selectedRegion!, _selectedProvince!);
          if (_selectedMunicipality != null) {
            _updateBarangays(_selectedRegion!, _selectedProvince!, _selectedMunicipality!);
          }
        }
      }
    } catch (e) {
      print('Error loading location data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _updateProvinces(String regionCode) {
    if (_locationData == null) return;
    
    final regionData = _locationData![regionCode];
    if (regionData != null && regionData['province_list'] != null) {
      final provinceList = regionData['province_list'] as Map<String, dynamic>;
      setState(() {
        _provinces = provinceList.keys.toList();
        _municipalities = [];
        _barangays = [];
        _selectedProvince = null;
        _selectedMunicipality = null;
        _selectedBarangay = null;
      });
    }
  }

  void _updateMunicipalities(String regionCode, String province) {
    print('DEBUG: _updateMunicipalities called with region: $regionCode, province: $province');
    if (_locationData == null) {
      print('DEBUG: _locationData is null');
      return;
    }
    
    final regionData = _locationData![regionCode];
    print('DEBUG: regionData: $regionData');
    if (regionData != null && regionData['province_list'] != null) {
      final provinceList = regionData['province_list'] as Map<String, dynamic>;
      print('DEBUG: provinceList keys: ${provinceList.keys.toList()}');
      final provinceData = provinceList[province];
      print('DEBUG: provinceData for $province: $provinceData');
      
      if (provinceData != null && provinceData['municipality_list'] != null) {
        final municipalityList = provinceData['municipality_list'] as Map<String, dynamic>;
        print('DEBUG: municipalityList: ${municipalityList.keys.toList()}');
        setState(() {
          _municipalities = municipalityList.keys.toList();
          _barangays = [];
          _selectedMunicipality = null;
          _selectedBarangay = null;
        });
      } else {
        print('DEBUG: provinceData is null or municipality_list is null');
      }
    } else {
      print('DEBUG: regionData is null or province_list is null');
    }
  }

  void _updateBarangays(String regionCode, String province, String municipality) {
    if (_locationData == null) return;
    
    final regionData = _locationData![regionCode];
    if (regionData != null && regionData['province_list'] != null) {
      final provinceList = regionData['province_list'] as Map<String, dynamic>;
      final provinceData = provinceList[province];
      
      if (provinceData != null && provinceData['municipality_list'] != null) {
        final municipalityList = provinceData['municipality_list'] as Map<String, dynamic>;
        final municipalityData = municipalityList[municipality];
        
        if (municipalityData != null && municipalityData['barangay_list'] != null) {
          final barangayList = municipalityData['barangay_list'] as List<dynamic>;
          setState(() {
            _barangays = barangayList.map((e) => e.toString()).toList();
            _selectedBarangay = null;
          });
        }
      }
    }
  }

  void _notifyLocationChanged() {
    widget.onLocationChanged(
      _selectedRegion,
      _selectedProvince,
      _selectedMunicipality,
      _selectedBarangay,
    );
  }

  String _getRegionName(String regionCode) {
    if (_locationData == null) return regionCode;
    return _locationData![regionCode]?['region_name']?.toString() ?? regionCode;
  }

  void _onRegionChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedRegion = value;
      _updateProvinces(value);
      _notifyLocationChanged();
    });
  }

  void _onProvinceChanged(String? value) {
    print('DEBUG: Province changed to: $value');
    print('DEBUG: Selected region: $_selectedRegion');
    if (value == null || _selectedRegion == null) return;
    setState(() {
      _selectedProvince = value;
      _updateMunicipalities(_selectedRegion!, value);
      _notifyLocationChanged();
    });
    print('DEBUG: Municipalities after update: $_municipalities');
  }

  void _onMunicipalityChanged(String? value) {
    if (value == null || _selectedRegion == null || _selectedProvince == null) return;
    setState(() {
      _selectedMunicipality = value;
      _updateBarangays(_selectedRegion!, _selectedProvince!, value);
      _notifyLocationChanged();
    });
  }

  void _onBarangayChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedBarangay = value;
      _notifyLocationChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Region Dropdown
        _buildDropdown(
          label: 'Region',
          value: _selectedRegion,
          items: _regions,
          hintText: 'Select Region',
          onChanged: _onRegionChanged,
          displayValue: (value) => _getRegionName(value),
        ),
        const SizedBox(height: 16),

        // Province Dropdown
        _buildDropdown(
          label: 'Province',
          value: _selectedProvince,
          items: _provinces,
          hintText: 'Select Province',
          onChanged: _onProvinceChanged,
          enabled: _selectedRegion != null,
        ),
        const SizedBox(height: 16),

        // Municipality Dropdown
        _buildDropdown(
          label: 'Municipality/City',
          value: _selectedMunicipality,
          items: _municipalities,
          hintText: 'Select Municipality/City',
          onChanged: _onMunicipalityChanged,
          enabled: _selectedProvince != null,
        ),
        const SizedBox(height: 16),

        // Barangay Dropdown
        _buildDropdown(
          label: 'Barangay',
          value: _selectedBarangay,
          items: _barangays,
          hintText: 'Select Barangay',
          onChanged: _onBarangayChanged,
          enabled: _selectedMunicipality != null,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required String hintText,
    Function(String?)? onChanged,
    String Function(String)? displayValue,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9E9E9E),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  displayValue != null ? displayValue(item) : item,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: enabled ? onChanged : null,
            hint: Text(
              hintText,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE81E0D), width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
            ),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE81E0D)),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}
