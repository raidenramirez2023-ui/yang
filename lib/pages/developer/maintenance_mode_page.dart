import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/audit_log_model.dart';
import '../../services/app_settings_service.dart';
import '../../services/audit_log_service.dart';
import 'developer_theme.dart';

class MaintenanceModePage extends StatefulWidget {
  final VoidCallback? onMaintenanceChanged;

  const MaintenanceModePage({super.key, this.onMaintenanceChanged});

  @override
  State<MaintenanceModePage> createState() => _MaintenanceModePageState();
}

class _MaintenanceModePageState extends State<MaintenanceModePage> {
  final AppSettingsService _settings = AppSettingsService();

  bool _isMaintenanceActive = false;
  String _currentReason = '';
  String _currentMessage = '';
  DateTime? _currentStartTime;
  DateTime? _currentEndTime;
  String? _currentUpdatedBy;

  bool _isSaving = false;
  List<AuditLog> _pastMaintenanceLogs = [];

  // Form Fields
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  DateTime? _formStartTime;
  TimeOfDay? _formStartTimeOfDay;
  DateTime? _formEndTime;
  TimeOfDay? _formEndTimeOfDay;

  final List<String> _presetReasons = [
    'Scheduled Database Migration & Index Optimization',
    'Core Infrastructure & Hosting Upgrade',
    'Emergency Patch & Bug Remediation',
    'Full System Backup & Cold Storage Sync',
    'Routine System Health Inspection',
    'Custom Reason',
  ];
  String _selectedPreset = 'Scheduled Database Migration & Index Optimization';

  @override
  void initState() {
    super.initState();
    _loadCurrentMaintenanceState();
    _loadMaintenanceHistory();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentMaintenanceState() async {
    await _settings.refreshSettings();

    final active = _settings.isMaintenanceModeEnabled();
    final reason = _settings.getMaintenanceReason();
    final message = _settings.getMaintenanceMessage();
    final startStr = _settings.getMaintenanceStartTime();
    final endStr = _settings.getMaintenanceEndTime();
    final updatedBy = _settings.getMaintenanceUpdatedBy();

    if (mounted) {
      setState(() {
        _isMaintenanceActive = active;
        _currentReason = reason;
        _currentMessage = message;
        _currentStartTime = (startStr != null && startStr.isNotEmpty) ? DateTime.tryParse(startStr) : null;
        _currentEndTime = (endStr != null && endStr.isNotEmpty) ? DateTime.tryParse(endStr) : null;
        _currentUpdatedBy = updatedBy;

        // Populate form fields with defaults
        if (!_isMaintenanceActive) {
          _reasonController.text = _selectedPreset;
          _messageController.text = message;
          final now = DateTime.now();
          _formStartTime = now;
          _formStartTimeOfDay = TimeOfDay.fromDateTime(now);
          final end = now.add(const Duration(hours: 2));
          _formEndTime = end;
          _formEndTimeOfDay = TimeOfDay.fromDateTime(end);
        } else {
          _reasonController.text = reason;
          _messageController.text = message;
          _formStartTime = _currentStartTime;
          if (_currentStartTime != null) {
            _formStartTimeOfDay = TimeOfDay.fromDateTime(_currentStartTime!);
          }
          _formEndTime = _currentEndTime;
          if (_currentEndTime != null) {
            _formEndTimeOfDay = TimeOfDay.fromDateTime(_currentEndTime!);
          }
        }
      });
    }
  }

  Future<void> _loadMaintenanceHistory() async {
    try {
      final logs = await AuditLogService.fetchLogs(
        action: 'MAINTENANCE_TOGGLE',
        limit: 10,
      );
      if (mounted) {
        setState(() => _pastMaintenanceLogs = logs);
      }
    } catch (_) {}
  }

  DateTime? _combineDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null) return null;
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _formStartTime ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => _darkPickerTheme(child),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _formStartTimeOfDay ?? TimeOfDay.fromDateTime(now),
        builder: (ctx, child) => _darkPickerTheme(child),
      );
      if (mounted) {
        setState(() {
          _formStartTime = pickedDate;
          if (pickedTime != null) _formStartTimeOfDay = pickedTime;
        });
      }
    }
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _formEndTime ?? now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => _darkPickerTheme(child),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _formEndTimeOfDay ?? TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
        builder: (ctx, child) => _darkPickerTheme(child),
      );
      if (mounted) {
        setState(() {
          _formEndTime = pickedDate;
          if (pickedTime != null) _formEndTimeOfDay = pickedTime;
        });
      }
    }
  }

  Widget _darkPickerTheme(Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: DeveloperTheme.accentIndigo,
          onPrimary: Colors.white,
          surface: DeveloperTheme.bgCard,
          onSurface: DeveloperTheme.textPrimary,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: DeveloperTheme.bgCard,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Future<void> _confirmToggleMaintenanceMode(bool targetEnable) async {
    final user = Supabase.instance.client.auth.currentUser;
    final developerEmail = user?.email ?? 'yangchowit@gmail.com';

    final reason = _reasonController.text.trim().isEmpty ? _selectedPreset : _reasonController.text.trim();
    final message = _messageController.text.trim();
    final startCombined = _combineDateTime(_formStartTime, _formStartTimeOfDay);
    final endCombined = _combineDateTime(_formEndTime, _formEndTimeOfDay);

    bool shouldPurgeTestData = !targetEnable; // Default true when disabling maintenance

    // Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: DeveloperTheme.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: targetEnable ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
                ),
              ),
              title: Row(
                children: [
                  Icon(
                    targetEnable ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                    color: targetEnable ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    targetEnable ? 'Confirm Enable Maintenance Mode' : 'Confirm Disable Maintenance Mode',
                    style: DeveloperTheme.headingMedium(),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    targetEnable
                        ? 'Enabling maintenance mode will flag the system as undergoing technical maintenance. Normal users are blocked while developer testing is permitted.'
                        : 'Disabling maintenance mode will immediately restore normal runtime state across all modules.',
                    style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DeveloperTheme.bgDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DeveloperTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Action: ${targetEnable ? "ACTIVATE MAINTENANCE" : "DEACTIVATE MAINTENANCE"}',
                            style: DeveloperTheme.monoText(
                              fontSize: 12,
                              color: targetEnable ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(height: 4),
                        Text('Reason: $reason', style: DeveloperTheme.bodySmall()),
                        if (startCombined != null) ...[
                          const SizedBox(height: 2),
                          Text('Start: ${DateFormat('yyyy-MM-dd HH:mm').format(startCombined)}',
                              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted)),
                        ],
                        if (endCombined != null) ...[
                          const SizedBox(height: 2),
                          Text('End: ${DateFormat('yyyy-MM-dd HH:mm').format(endCombined)}',
                              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted)),
                        ],
                        const SizedBox(height: 4),
                        Text('Authorized by: $developerEmail',
                            style: DeveloperTheme.monoText(fontSize: 11, color: DeveloperTheme.accentCyan)),
                      ],
                    ),
                  ),
                  if (!targetEnable) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DeveloperTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: DeveloperTheme.accentRose.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: shouldPurgeTestData,
                            activeColor: DeveloperTheme.accentRose,
                            checkColor: Colors.white,
                            onChanged: (val) {
                              setDialogState(() {
                                shouldPurgeTestData = val ?? false;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-purge test payments & orders',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: DeveloperTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Deletes orders, payments & test reservations created during this maintenance so admin sales reports stay clean.',
                                  style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: targetEnable ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(targetEnable ? 'Yes, Enable Maintenance' : 'Yes, Restore Normal Runtime'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        Map<String, int>? purgeResults;
        if (!targetEnable && shouldPurgeTestData) {
          purgeResults = await _settings.purgeMaintenanceTestData(
            windowStartTime: _currentStartTime,
            operatorEmail: developerEmail,
          );
        }

        await _settings.setMaintenanceMode(
          enabled: targetEnable,
          reason: reason,
          message: message,
          startTime: startCombined,
          endTime: endCombined,
          updatedBy: developerEmail,
        );

        // Immutable Audit Log
        final purgeSummary = purgeResults != null
            ? ' Purged ${purgeResults['orders']} test orders and ${purgeResults['reservations']} test reservations.'
            : '';
        await AuditLogService.logActivity(
          action: 'MAINTENANCE_TOGGLE',
          module: 'Maintenance',
          description: targetEnable
              ? 'Developer enabled system maintenance mode: "$reason"'
              : 'Developer disabled maintenance mode. Normal operations restored.$purgeSummary',
          customUserEmail: developerEmail,
          customUserRole: 'DEVELOPER',
          metadata: {
            'maintenance_mode_enabled': targetEnable,
            'reason': reason,
            'message': message,
            'start_time': startCombined?.toIso8601String(),
            'end_time': endCombined?.toIso8601String(),
            'operator': developerEmail,
            'purged_orders': purgeResults?['orders'] ?? 0,
            'purged_reservations': purgeResults?['reservations'] ?? 0,
            'purged_advance_orders': purgeResults?['advance_orders'] ?? 0,
          },
        );

        await _loadCurrentMaintenanceState();
        await _loadMaintenanceHistory();
        widget.onMaintenanceChanged?.call();

        if (mounted) {
          final totalPurged = (purgeResults?['orders'] ?? 0) +
              (purgeResults?['reservations'] ?? 0) +
              (purgeResults?['advance_orders'] ?? 0);
          final messageText = targetEnable
              ? 'Maintenance Mode successfully ACTIVATED.'
              : (purgeResults != null && totalPurged > 0)
                  ? 'Maintenance DEACTIVATED & Purged ${purgeResults['orders']} orders, ${purgeResults['reservations']} events/reservations, and ${purgeResults['advance_orders']} advance orders.'
                  : 'Maintenance Mode successfully DEACTIVATED.';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: targetEnable ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
              content: Text(
                messageText,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: DeveloperTheme.accentRose,
              content: Text('Failed to update maintenance mode: $e'),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  Future<void> _showManualPurgeDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    final developerEmail = user?.email ?? 'developer@yangchow.com';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: DeveloperTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: DeveloperTheme.accentRose),
          ),
          title: Row(
            children: [
              const Icon(Icons.delete_sweep_rounded, color: DeveloperTheme.accentRose),
              const SizedBox(width: 10),
              Text('Purge Test Payments & Orders', style: DeveloperTheme.headingMedium()),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete all test orders, payments, order items, and test reservations created during this maintenance session (or with test indicators / developer email).',
                style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DeveloperTheme.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DeveloperTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Target Tables: orders, order_items, reservations, refunds',
                        style: DeveloperTheme.monoText(fontSize: 11, color: DeveloperTheme.accentAmber)),
                    const SizedBox(height: 4),
                    Text(
                      'Window: Since ${_currentStartTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(_currentStartTime!) : "last 4 hours"}',
                      style: DeveloperTheme.monoText(fontSize: 11, color: DeveloperTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DeveloperTheme.accentRose,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Purge Test Records Now'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        final res = await _settings.purgeMaintenanceTestData(
          windowStartTime: _currentStartTime,
          operatorEmail: developerEmail,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: DeveloperTheme.accentEmerald,
              content: Text(
                'Purged ${res['orders']} test orders, ${res['reservations']} events/reservations, and ${res['advance_orders']} advance orders.',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: DeveloperTheme.accentRose,
              content: Text('Error purging test records: $e'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final startCombined = _combineDateTime(_formStartTime, _formStartTimeOfDay);
    final endCombined = _combineDateTime(_formEndTime, _formEndTimeOfDay);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maintenance Mode Control', style: DeveloperTheme.headingLarge()),
                  const SizedBox(height: 4),
                  Text(
                    'Safely pause customer/guest traffic during planned infrastructure updates or urgent fixes',
                    style: DeveloperTheme.bodySmall(),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _loadCurrentMaintenanceState,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DeveloperTheme.bgCardHover,
                  foregroundColor: DeveloperTheme.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Primary Status Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: DeveloperTheme.cardDecoration(
              borderColor: _isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
              glow: true,
              glowColor: _isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (_isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isMaintenanceActive ? Icons.build_circle_rounded : Icons.verified_rounded,
                    color: _isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _isMaintenanceActive ? 'MAINTENANCE MODE ACTIVE' : 'SYSTEM RUNTIME OPERATIONAL',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: (_isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isMaintenanceActive ? 'TECHNICAL WINDOW' : 'NORMAL TRAFFIC',
                              style: DeveloperTheme.monoText(
                                fontSize: 11,
                                color: _isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isMaintenanceActive
                            ? 'Reason: $_currentReason'
                            : 'All customer reservations, online ordering, staff POS, chef kitchen, and inventory flows are running without restriction.',
                        style: DeveloperTheme.bodySmall(color: DeveloperTheme.textPrimary),
                      ),
                      if (_isMaintenanceActive) ...[
                        if (_currentMessage.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Notice: "$_currentMessage"',
                            style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 4),
                        if (_currentStartTime != null || _currentEndTime != null)
                          Text(
                            'Scheduled: ${_currentStartTime != null ? DateFormat('MMM dd, yyyy HH:mm').format(_currentStartTime!) : "Now"} — ${_currentEndTime != null ? DateFormat('MMM dd, yyyy HH:mm').format(_currentEndTime!) : "Indefinite"}',
                            style: DeveloperTheme.monoText(fontSize: 12, color: DeveloperTheme.accentCyan),
                          ),
                        if (_currentUpdatedBy != null) ...[
                          const SizedBox(height: 2),
                          Text('Last Modified By: $_currentUpdatedBy',
                              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted)),
                        ],
                      ],
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _confirmToggleMaintenanceMode(!_isMaintenanceActive),
                  icon: Icon(
                    _isMaintenanceActive ? Icons.power_settings_new_rounded : Icons.build,
                    size: 18,
                  ),
                  label: Text(_isMaintenanceActive ? 'Deactivate Maintenance' : 'Activate Maintenance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isMaintenanceActive ? DeveloperTheme.accentEmerald : DeveloperTheme.accentAmber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Maintenance Configuration Form
          Text('Maintenance Parameters & Window', style: DeveloperTheme.headingMedium()),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: DeveloperTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reason preset selection
                Text('Maintenance Reason Preset', style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: DeveloperTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DeveloperTheme.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPreset,
                      dropdownColor: DeveloperTheme.bgCard,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: DeveloperTheme.textSecondary),
                      style: GoogleFonts.inter(fontSize: 13, color: DeveloperTheme.textPrimary),
                      items: _presetReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedPreset = val;
                            if (val != 'Custom Reason') {
                              _reasonController.text = val;
                            } else {
                              _reasonController.clear();
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Editable reason text field
                Text('Specified Reason', style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  style: GoogleFonts.inter(fontSize: 13, color: DeveloperTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter technical maintenance reason...',
                    hintStyle: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                    filled: true,
                    fillColor: DeveloperTheme.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Custom User Notice Message
                Text('User-Facing Notice Message (Optional)',
                    style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 13, color: DeveloperTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Message displayed to customers if maintenance banner is active...',
                    hintStyle: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                    filled: true,
                    fillColor: DeveloperTheme.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Start / End Window Pickers
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Maintenance Start Time',
                              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectStartDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: DeveloperTheme.bgDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: DeveloperTheme.borderSubtle),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    startCombined != null
                                        ? DateFormat('yyyy-MM-dd HH:mm').format(startCombined)
                                        : 'Select Start Time',
                                    style: DeveloperTheme.monoText(
                                      fontSize: 13,
                                      color: DeveloperTheme.textPrimary,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_rounded,
                                      size: 16, color: DeveloperTheme.accentCyan),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estimated End Time',
                              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectEndDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: DeveloperTheme.bgDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: DeveloperTheme.borderSubtle),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    endCombined != null
                                        ? DateFormat('yyyy-MM-dd HH:mm').format(endCombined)
                                        : 'Select End Time',
                                    style: DeveloperTheme.monoText(
                                      fontSize: 13,
                                      color: DeveloperTheme.textPrimary,
                                    ),
                                  ),
                                  const Icon(Icons.event_available_rounded,
                                      size: 16, color: DeveloperTheme.accentIndigo),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Save / Update button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => _confirmToggleMaintenanceMode(_isMaintenanceActive),
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Update Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DeveloperTheme.accentIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Maintenance Test Data Purge Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: DeveloperTheme.cardDecoration(
              borderColor: DeveloperTheme.accentRose.withValues(alpha: 0.35),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DeveloperTheme.accentRose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_sweep_rounded, color: DeveloperTheme.accentRose, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purge Maintenance Test Payments & Orders',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DeveloperTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Permanently delete all test orders, payments, order items, and test reservations created during maintenance mode. Keeps the Admin daily/monthly sales reports accurate.',
                        style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _showManualPurgeDialog,
                  icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                  label: const Text('Purge Test Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DeveloperTheme.accentRose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Maintenance History Audit
          Text('Maintenance Mode Audit Trail', style: DeveloperTheme.headingMedium()),
          const SizedBox(height: 12),

          _pastMaintenanceLogs.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: DeveloperTheme.cardDecoration(),
                  alignment: Alignment.center,
                  child: Text('No previous maintenance toggle events on record',
                      style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pastMaintenanceLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = _pastMaintenanceLogs[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: DeveloperTheme.cardDecoration(),
                      child: Row(
                        children: [
                          Icon(Icons.history_rounded, size: 18, color: DeveloperTheme.accentAmber),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.description,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: DeveloperTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'By: ${log.userEmail}',
                                  style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(log.createdAt),
                            style: DeveloperTheme.monoText(fontSize: 11, color: DeveloperTheme.textSecondary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
