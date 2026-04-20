import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class InteractiveTableMap extends StatefulWidget {
  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> availableTables;
  final String? selectedTableId;
  final Function(String) onTableSelected;

  const InteractiveTableMap({
    super.key,
    required this.tables,
    required this.availableTables,
    this.selectedTableId,
    required this.onTableSelected,
  });

  @override
  State<InteractiveTableMap> createState() => _InteractiveTableMapState();
}

class _InteractiveTableMapState extends State<InteractiveTableMap> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          // Background Grid / Pattern
          CustomPaint(
            size: Size.infinite,
            painter: _FloorPlanPainter(),
          ),
          
          // Tables
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: widget.tables.map((table) {
                  final String tableId = table['id'];
                  final int tableNumber = table['table_number'];
                  final int capacity = table['capacity'];
                  final double x = table['x_pos'] ?? 0.0;
                  final double y = table['y_pos'] ?? 0.0;
                  
                  final bool isAvailable = widget.availableTables.any((t) => t['id'] == tableId);
                  final bool isSelected = widget.selectedTableId == tableId;
                  
                  return Positioned(
                    left: x * constraints.maxWidth,
                    top: y * constraints.maxHeight,
                    child: GestureDetector(
                      onTap: isAvailable ? () => widget.onTableSelected(tableId) : null,
                      child: _buildTableIcon(
                        number: tableNumber,
                        capacity: capacity,
                        isSelected: isSelected,
                        isAvailable: isAvailable,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          
          // Legend
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem(Colors.green, 'Available'),
                  const SizedBox(height: 4),
                  _buildLegendItem(AppTheme.primaryColor, 'Selected'),
                  const SizedBox(height: 4),
                  _buildLegendItem(Colors.grey.shade400, 'Reserved'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTableIcon({
    required int number,
    required int capacity,
    required bool isSelected,
    required bool isAvailable,
  }) {
    Color color = Colors.grey.shade400;
    if (isSelected) {
      color = AppTheme.primaryColor;
    } else if (isAvailable) {
      color = Colors.green;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)] : null,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Text('$capacity pax', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }
}

class _FloorPlanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    // Draw grid lines
    for (double i = 0; i <= size.width; i += 50) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += 50) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
