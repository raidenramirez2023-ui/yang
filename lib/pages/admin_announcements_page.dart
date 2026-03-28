import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _announcements = [];

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  DateTime? _expirationDate;
  bool _autoExpireBasedOnEvents = true;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _announcements = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading announcements: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addOrUpdateAnnouncement({String? id}) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    Navigator.pop(context); // Close dialog

    try {
      DateTime? expirationToUse;
      
      if (_autoExpireBasedOnEvents) {
        // Auto-calculate expiration based on next event
        final nextEvent = await _getNextRelatedEvent(title);
        if (nextEvent != null) {
          final eventDate = DateTime.parse(nextEvent['event_date']);
          final startTime = nextEvent['start_time'];
          
          // Parse start time and add event duration
          DateTime eventEnd;
          if (startTime.toUpperCase().contains('AM') || startTime.toUpperCase().contains('PM')) {
            DateTime parsedTime = DateFormat.jm().parse(startTime.trim());
            eventEnd = DateTime(
              eventDate.year,
              eventDate.month,
              eventDate.day,
              parsedTime.hour,
              parsedTime.minute,
            ).add(Duration(hours: nextEvent['duration_hours'] ?? 4));
          } else {
            eventEnd = DateTime.parse('${eventDate}T${startTime}:00')
                .add(Duration(hours: nextEvent['duration_hours'] ?? 4));
          }
          expirationToUse = eventEnd;
        } else {
          // No related event found, set default 7 days from now
          expirationToUse = DateTime.now().add(const Duration(days: 7));
        }
      } else {
        expirationToUse = _expirationDate;
      }
      
      if (id == null) {
        // Add new
        await _supabase.from('announcements').insert({
          'title': title,
          'content': content,
          'is_active': true,
          'expiration_date': expirationToUse?.toIso8601String(),
        });
      } else {
        // Update existing
        await _supabase.from('announcements').update({
          'title': title,
          'content': content,
          'expiration_date': expirationToUse?.toIso8601String(),
        }).eq('id', id);
      }
      
      _titleController.clear();
      _contentController.clear();
      _expirationDate = null;
      _autoExpireBasedOnEvents = true;
      await _fetchAnnouncements();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(id == null ? 'Announcement added' : 'Announcement updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving announcement: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _getNextRelatedEvent(String title) async {
    try {
      // Extract event type from title or search for related keywords
      final keywords = ['wedding', 'birthday', 'corporate', 'party', 'event'];
      String? matchingKeyword;
      
      for (final keyword in keywords) {
        if (title.toLowerCase().contains(keyword)) {
          matchingKeyword = keyword;
          break;
        }
      }
      
      if (matchingKeyword != null) {
        final response = await _supabase
            .from('reservations')
            .select('*')
            .eq('status', 'confirmed')
            .ilike('event_type', '%$matchingKeyword%')
            .gte('event_date', DateTime.now().toIso8601String())
            .order('event_date', ascending: true)
            .limit(1)
            .maybeSingle();
            
        return response;
      }
      
      // If no keyword match, get the next confirmed event
      final response = await _supabase
          .from('reservations')
          .select('*')
          .eq('status', 'confirmed')
          .gte('event_date', DateTime.now().toIso8601String())
          .order('event_date', ascending: true)
          .limit(1)
          .maybeSingle();
          
      return response;
    } catch (e) {
      debugPrint('Error getting next related event: $e');
      return null;
    }
  }

  Future<void> _toggleStatus(String id, bool currentStatus) async {
    try {
      setState(() => _isLoading = true);
      await _supabase.from('announcements').update({
        'is_active': !currentStatus,
      }).eq('id', id);
      
      await _fetchAnnouncements();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    try {
      setState(() => _isLoading = true);
      await _supabase.from('announcements').delete().eq('id', id);
      await _fetchAnnouncements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting announcement: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFormDialog({Map<String, dynamic>? announcement}) {
    if (announcement != null) {
      _titleController.text = announcement['title'];
      _contentController.text = announcement['content'];
      if (announcement['expiration_date'] != null) {
        _expirationDate = DateTime.tryParse(announcement['expiration_date']);
        _autoExpireBasedOnEvents = false;
      }
    } else {
      _titleController.clear();
      _contentController.clear();
      _expirationDate = null;
      _autoExpireBasedOnEvents = true;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(announcement == null ? 'New Announcement' : 'Edit Announcement'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Expiration options
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expiration Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Auto-expire based on events checkbox
                      CheckboxListTile(
                        title: Text(
                          'Auto-expire based on event schedule',
                          style: TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          'Automatically hide when related event ends',
                          style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                        ),
                        value: _autoExpireBasedOnEvents,
                        onChanged: (value) {
                          setState(() {
                            _autoExpireBasedOnEvents = value ?? true;
                            if (_autoExpireBasedOnEvents) {
                              _expirationDate = null;
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      // Manual expiration date picker
                      if (!_autoExpireBasedOnEvents) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          title: Text(
                            'Expiration Date',
                            style: TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            _expirationDate != null
                                ? DateFormat('MMM dd, yyyy - HH:mm').format(_expirationDate!)
                                : 'Select expiration date',
                            style: TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
                          ),
                          trailing: Icon(Icons.calendar_today, size: 18),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _expirationDate ?? DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                  _expirationDate ?? DateTime.now().add(const Duration(days: 7))
                                ),
                              );
                              
                              if (time != null) {
                                setState(() {
                                  _expirationDate = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _titleController.clear();
                _contentController.clear();
                _expirationDate = null;
                _autoExpireBasedOnEvents = true;
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _addOrUpdateAnnouncement(id: announcement?['id']),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('Save', style: TextStyle(color: AppTheme.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Announcements',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showFormDialog(),
                    icon: const Icon(Icons.add, color: AppTheme.white),
                    label: const Text('New Announcement', style: TextStyle(color: AppTheme.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _announcements.isEmpty
                ? const Center(child: Text('No announcements found', style: TextStyle(color: AppTheme.mediumGrey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _announcements.length,
                    itemBuilder: (context, index) {
                      final item = _announcements[index];
                      final dateStr = item['created_at'].toString().split('T').first;
                      final isActive = item['is_active'] as bool;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title row with status
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      item['title'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        color: isActive ? Colors.green : Colors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Date
                              Text(
                                dateStr, 
                                style: const TextStyle(
                                  color: AppTheme.primaryColor, 
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Content
                              Text(
                                item['content'],
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              // Action buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(isActive ? Icons.visibility_off : Icons.visibility),
                                    tooltip: isActive ? 'Deactivate' : 'Activate',
                                    onPressed: () => _toggleStatus(item['id'], isActive),
                                    iconSize: 20,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'Edit',
                                    onPressed: () => _showFormDialog(announcement: item),
                                    iconSize: 20,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Delete',
                                    onPressed: () => _showDeleteConfirmDialog(item['id']),
                                    iconSize: 20,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this announcement? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAnnouncement(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete', style: TextStyle(color: AppTheme.white)),
          ),
        ],
      ),
    );
  }
}
