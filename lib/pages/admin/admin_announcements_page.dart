import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/services/audit_log_service.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> announcements = [];
  bool isLoading = true;
  bool _isCreateExpanded = false;
  String _selectedFilter = 'All'; // All, Active, Expired, Inactive
  int _currentPage = 1;
  static const int _itemsPerPage = 15;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();
  final TextEditingController tagController = TextEditingController();
  DateTime? selectedDate;

  // Color constants
  static const _darkBg = Color(0xFF0F172A);
  static const _emerald = Color(0xFF14332E);
  static const _gold = Color(0xFFD9A441);
  static const _slate = Color(0xFF64748B);
  static const _slateLight = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    imageUrlController.dispose();
    tagController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    try {
      setState(() {
        isLoading = true;
        _currentPage = 1;
      });

      final response = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          announcements = List<Map<String, dynamic>>.from(response as List);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading announcements: $e', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _addAnnouncement() async {
    if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter title and content', style: GoogleFonts.plusJakartaSans()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    try {
      final inserted = await supabase.from('announcements').insert({
        'title': titleController.text.trim(),
        'content': contentController.text.trim(),
        'image_url': imageUrlController.text.trim().isEmpty ? null : imageUrlController.text.trim(),
        'tag': tagController.text.trim().isEmpty ? 'Promo' : tagController.text.trim(),
        'is_active': true,
        'expiration_date': selectedDate?.toUtc().toIso8601String(),
      }).select('id').maybeSingle();

      AuditLogService.logActivity(
        action: 'CREATE',
        module: 'Announcements',
        description: 'Published announcement: "${titleController.text.trim()}"',
        entityId: inserted?['id']?.toString(),
        metadata: {
          'title': titleController.text.trim(),
          'tag': tagController.text.trim(),
          'expires_at': selectedDate?.toIso8601String(),
        },
      );

      if (mounted) {
        titleController.clear();
        contentController.clear();
        imageUrlController.clear();
        tagController.clear();
        selectedDate = null;
        setState(() => _isCreateExpanded = false);
        _loadAnnouncements();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Announcement published successfully', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: _emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating announcement: $e', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement(String announcementId) async {
    try {
      await supabase.from('announcements').delete().eq('id', announcementId);

      AuditLogService.logActivity(
        action: 'DELETE',
        module: 'Announcements',
        description: 'Deleted announcement #$announcementId',
        entityId: announcementId,
      );

      if (mounted) {
        _loadAnnouncements();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Announcement removed', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting announcement: $e', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _toggleActive(String announcementId, bool currentStatus) async {
    try {
      await supabase
          .from('announcements')
          .update({'is_active': !currentStatus})
          .eq('id', announcementId);

      AuditLogService.logActivity(
        action: 'STATUS_CHANGE',
        module: 'Announcements',
        description: 'Changed status to ${!currentStatus ? "ACTIVE" : "INACTIVE"}',
        entityId: announcementId,
        metadata: {'is_active': !currentStatus},
      );

      if (mounted) {
        _loadAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating announcement: $e', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAnnouncements {
    final now = DateTime.now();
    return announcements.where((a) {
      final isActive = a['is_active'] ?? false;
      final rawExpires = a['expiration_date'] ?? a['expires_at'];
      final expiresAt = rawExpires != null ? DateTime.tryParse(rawExpires.toString()) : null;
      final isExpired = expiresAt != null && expiresAt.isBefore(now);

      if (_selectedFilter == 'Active') return isActive && !isExpired;
      if (_selectedFilter == 'Expired') return isExpired;
      if (_selectedFilter == 'Inactive') return !isActive && !isExpired;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final filtered = _filteredAnnouncements;

    // Analytics computation
    final now = DateTime.now();
    final totalCount = announcements.length;
    final activeCount = announcements.where((a) {
      final isActive = a['is_active'] ?? false;
      final rawExpires = a['expiration_date'] ?? a['expires_at'];
      final expiresAt = rawExpires != null ? DateTime.tryParse(rawExpires.toString()) : null;
      return isActive && (expiresAt == null || expiresAt.isAfter(now));
    }).length;

    final expiringSoonCount = announcements.where((a) {
      final isActive = a['is_active'] ?? false;
      final rawExpires = a['expiration_date'] ?? a['expires_at'];
      final expiresAt = rawExpires != null ? DateTime.tryParse(rawExpires.toString()) : null;
      if (!isActive || expiresAt == null) return false;
      final diff = expiresAt.difference(now).inDays;
      return diff >= 0 && diff <= 3;
    }).length;

    // Pagination calculations (15 items per page)
    final totalItems = filtered.length;
    final totalPages = totalItems > 0 ? (totalItems / _itemsPerPage).ceil() : 1;
    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    if (_currentPage < 1) {
      _currentPage = 1;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < totalItems)
        ? startIndex + _itemsPerPage
        : totalItems;

    final paginatedAnnouncements = totalItems > 0
        ? filtered.sublist(startIndex, endIndex)
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadAnnouncements,
        color: _gold,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 12 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 14),
              _buildStatsRow(isMobile, totalCount, activeCount, expiringSoonCount),
              const SizedBox(height: 14),
              _buildCreateSection(isMobile),
              const SizedBox(height: 16),
              _buildFilterToolbar(isMobile),
              const SizedBox(height: 14),
              if (isLoading)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: _gold),
                )
              else if (filtered.isEmpty)
                _buildEmptyState()
              else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paginatedAnnouncements.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildAnnouncementCard(paginatedAnnouncements[index], isMobile),
                ),
                _buildAnnouncementPagination(
                  totalItems: totalItems,
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_emerald, Color(0xFF1E4A42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _emerald.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.campaign_rounded, color: _gold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Announcements & Promos',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 16 : 20,
                        fontWeight: FontWeight.w800,
                        color: _darkBg,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Customer Facing',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9E6D10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Publish promotions, holiday schedules, and event notices to the customer app',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 11 : 12,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadAnnouncements,
            icon: const Icon(Icons.refresh_rounded, color: _slate, size: 20),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isMobile, int total, int active, int expiringSoon) {
    final tiles = [
      _buildStatTile(
        label: 'Total Notices',
        value: total.toString(),
        icon: Icons.campaign_rounded,
        bgTint: const Color(0xFFE0F2FE),
        iconColor: const Color(0xFF0284C7),
      ),
      _buildStatTile(
        label: 'Active & Live',
        value: active.toString(),
        icon: Icons.check_circle_rounded,
        bgTint: const Color(0xFFDCFCE7),
        iconColor: const Color(0xFF15803D),
      ),
      _buildStatTile(
        label: 'Expiring Soon',
        value: expiringSoon.toString(),
        icon: Icons.hourglass_bottom_rounded,
        bgTint: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 66,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: tiles
              .map((t) => Container(
                    width: 155,
                    margin: const EdgeInsets.only(right: 8),
                    child: t,
                  ))
              .toList(),
        ),
      );
    }

    return Row(
      children: tiles
          .map((t) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: t,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color bgTint,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _darkBg,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateSection(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _isCreateExpanded = !_isCreateExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _emerald.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_circle_outline_rounded, color: _emerald, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Create New Announcement',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isMobile ? 14 : 15,
                            fontWeight: FontWeight.w800,
                            color: _darkBg,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _isCreateExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: _slate,
                    ),
                  ],
                ),
              ),
            ),
            if (_isCreateExpanded) ...[
              const Divider(height: 1, color: _slateLight),
              Padding(
                padding: EdgeInsets.all(isMobile ? 14 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        hintText: 'e.g. Weekend Dim Sum Promo, Holy Week Hours',
                        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                        prefixIcon: const Icon(Icons.title_rounded, size: 18, color: _slate),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 3,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Content Description *',
                        hintText: 'Details about the announcement, discounts, or schedules...',
                        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                        prefixIcon: const Icon(Icons.description_rounded, size: 18, color: _slate),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isMobile) ...[
                      TextField(
                        controller: tagController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Tag (Optional)',
                          hintText: 'Promo, Seasonal, Update, Notice',
                          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                          prefixIcon: const Icon(Icons.label_outline_rounded, size: 18, color: _slate),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageUrlController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Image URL (Optional)',
                          hintText: 'https://example.com/banner.jpg',
                          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                          prefixIcon: const Icon(Icons.image_outlined, size: 18, color: _slate),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tagController,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Tag (Optional)',
                                hintText: 'Promo, Seasonal, Update',
                                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                                prefixIcon: const Icon(Icons.label_outline_rounded, size: 18, color: _slate),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: imageUrlController,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Image URL (Optional)',
                                hintText: 'https://example.com/banner.jpg',
                                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                                prefixIcon: const Icon(Icons.image_outlined, size: 18, color: _slate),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() => selectedDate = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Expiration Date (Optional)',
                                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                                prefixIcon: const Icon(Icons.event_rounded, size: 18, color: _slate),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              child: Text(
                                selectedDate == null
                                    ? 'No expiry (Permanent)'
                                    : DateFormat('MMM dd, yyyy').format(selectedDate!),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: selectedDate != null ? FontWeight.w700 : FontWeight.w500,
                                  color: selectedDate != null ? _emerald : _slate,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (selectedDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, color: _slate, size: 18),
                            onPressed: () => setState(() => selectedDate = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _addAnnouncement,
                        icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'Publish Announcement',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _emerald,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterToolbar(bool isMobile) {
    final filters = ['All', 'Active', 'Expired', 'Inactive'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() {
                _selectedFilter = f;
                _currentPage = 1;
              }),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? _emerald : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _emerald : _slateLight,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _emerald.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  f,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnnouncementPagination({
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = ((currentPage - 1) * _itemsPerPage) + 1;
    final endItem = (currentPage * _itemsPerPage < totalItems)
        ? currentPage * _itemsPerPage
        : totalItems;

    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $startItem–$endItem of $totalItems notices',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _slate,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _emerald,
                  ),
                ),
              ),
            ],
          ),
          if (totalPages > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Prev Button
                InkWell(
                  onTap: currentPage > 1
                      ? () => onPageChanged(currentPage - 1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentPage > 1 ? _emerald : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: currentPage > 1 ? _emerald : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: currentPage > 1 ? Colors.white : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Prev',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: currentPage > 1 ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Page Number Buttons with smart ellipsis window
                ...List.generate(totalPages, (index) {
                  final pageNum = index + 1;
                  if (totalPages > 5) {
                    if (pageNum != 1 &&
                        pageNum != totalPages &&
                        (pageNum < currentPage - 1 || pageNum > currentPage + 1)) {
                      if (pageNum == currentPage - 2 || pageNum == currentPage + 2) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '…',
                            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                  }

                  final isSelected = pageNum == currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () {
                        if (!isSelected) {
                          onPageChanged(pageNum);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? _gold : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? _gold : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _gold.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '$pageNum',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected ? _emerald : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(width: 8),

                // Next Button
                InkWell(
                  onTap: currentPage < totalPages
                      ? () => onPageChanged(currentPage + 1)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentPage < totalPages ? _emerald : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: currentPage < totalPages ? _emerald : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: currentPage < totalPages ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: currentPage < totalPages ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement, bool isMobile) {
    final id = announcement['id']?.toString() ?? '';
    final title = announcement['title']?.toString() ?? 'Untitled';
    final content = announcement['content']?.toString() ?? '';
    final tag = announcement['tag']?.toString() ?? 'Promo';
    final imageUrl = announcement['image_url']?.toString();
    final isActive = announcement['is_active'] ?? false;

    final rawExpires = announcement['expiration_date'] ?? announcement['expires_at'];
    final expiresAt = rawExpires != null ? DateTime.tryParse(rawExpires.toString()) : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    Color statusColor;
    String statusText;
    if (isExpired) {
      statusColor = const Color(0xFFDC2626);
      statusText = 'Expired';
    } else if (isActive) {
      statusColor = const Color(0xFF15803D);
      statusText = 'Active';
    } else {
      statusColor = const Color(0xFF64748B);
      statusText = 'Inactive';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: statusColor,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  tag.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF9E6D10),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 6, color: statusColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusText,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (expiresAt != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_outlined, size: 12, color: _slate),
                                const SizedBox(width: 4),
                                Text(
                                  'Expires ${DateFormat('MMM dd').format(expiresAt)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    color: _slate,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w800,
                          color: _darkBg,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: _slate,
                          height: 1.35,
                        ),
                      ),
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => _showImagePreviewDialog(context, imageUrl, title),
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  constraints: BoxConstraints(
                                    minHeight: isMobile ? 170 : 230,
                                    maxHeight: isMobile ? 220 : 320,
                                  ),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: isMobile ? 170 : 230,
                                        color: const Color(0xFFF8FAFC),
                                        child: const Center(
                                          child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
                                        ),
                                      );
                                    },
                                    errorBuilder: (c, e, s) => Container(
                                      height: 140,
                                      color: const Color(0xFFF1F5F9),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.broken_image_rounded, color: _slate, size: 32),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Failed to load image',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                      const SizedBox(width: 5),
                                      Text(
                                        'View Full Image',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _toggleActive(id, isActive),
                            icon: Icon(
                              isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 14,
                            ),
                            label: Text(isActive ? 'Deactivate' : 'Activate'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              textStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _deleteAnnouncement(id),
                            icon: const Icon(Icons.delete_outline_rounded, size: 14),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              textStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImagePreviewDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                  child: Row(
                    children: [
                      const Icon(Icons.image_rounded, color: _gold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _darkBg,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20, color: _slate),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Flexible(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    child: Container(
                      color: const Color(0xFF0F172A),
                      alignment: Alignment.center,
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(color: _gold),
                            );
                          },
                          errorBuilder: (c, e, s) => Container(
                            height: 240,
                            color: const Color(0xFF1E293B),
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_outlined, size: 40, color: _gold),
          ),
          const SizedBox(height: 14),
          Text(
            'No Announcements Found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _darkBg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Create New Announcement" above to publish your first customer notice.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}