import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';

import '../../config/theme.dart';
import '../../services/core_service.dart';
import '../../services/notification_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _alerts = [];
  List<dynamic> _strangerEvents = [];
  List<dynamic> _allEvents = [];
  int _unackCount = 0;
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      CoreService.getAlerts(acknowledged: false, limit: 100),
      CoreService.getEvents(result: 'stranger', limit: 50),
      CoreService.getEvents(limit: 100),
    ]);

    if (mounted) {
      setState(() {
        if (results[0].success) {
          _alerts = results[0].data['alerts'] ?? [];
          _unackCount = results[0].data['unacknowledged_count'] ?? 0;
        }
        if (results[1].success) {
          _strangerEvents = results[1].data['events'] ?? [];
        }
        if (results[2].success) {
          _allEvents = results[2].data['events'] ?? [];
        }
        _loading = false;
      });
    }
  }

  Future<void> _acknowledgeAll() async {
    final resp = await CoreService.acknowledgeAllAlerts();
    if (resp.success) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textMuted,
                    labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Alerts'),
                          if (_unackCount > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.danger,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text('$_unackCount',
                                style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ],
                        ],
                      )),
                      const Tab(text: 'Strangers'),
                      const Tab(text: 'All'),
                    ],
                  ),
                ),
              ),
              if (_unackCount > 0 && _tabCtrl.index == 0) ...[
                const SizedBox(width: 10),
                _iconActionButton(
                  icon: IconlyBold.tick_square,
                  color: AppTheme.success,
                  tooltip: 'Acknowledge All',
                  onTap: _acknowledgeAll,
                ),
              ],
              const SizedBox(width: 8),
              _iconActionButton(
                icon: IconlyBold.notification,
                color: AppTheme.primary,
                tooltip: 'Test Notification',
                onTap: () async {
                  await NotificationService.showTestNotification();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Test notification sent!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _buildContent(),
        ),
      ],
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_tabCtrl.index) {
      case 0: return _buildAlertsList();
      case 1: return _buildStrangersList();
      case 2: return _buildAllEventsList();
      default: return const SizedBox();
    }
  }

  Widget _buildAlertsList() {
    if (_alerts.isEmpty) {
      return _emptyState(
        icon: IconlyBold.shield_done,
        color: AppTheme.success,
        title: 'All clear!',
        subtitle: 'No security alerts',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _alerts.length,
        itemBuilder: (_, i) => _buildAlertCard(_alerts[i], i),
      ),
    );
  }

  Widget _buildStrangersList() {
    final strangers = _strangerEvents;

    if (strangers.isEmpty) {
      return _emptyState(
        icon: IconlyBold.shield_done,
        color: AppTheme.success,
        title: 'No strangers detected',
        subtitle: 'Your home is secure',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: strangers.length,
        itemBuilder: (_, i) => _buildEventCard(strangers[i], i),
      ),
    );
  }

  Widget _buildAllEventsList() {
    if (_allEvents.isEmpty) {
      return _emptyState(
        icon: IconlyBold.activity,
        color: AppTheme.textMuted,
        title: 'No events yet',
        subtitle: 'Detection events will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _allEvents.length,
        itemBuilder: (_, i) => _buildEventCard(_allEvents[i], i),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> a, int i) {
    final ack = a['is_acknowledged'] == true;
    final severity = a['severity'] ?? 'medium';
    final color = _severityColor(severity);
    final hasImage = a['image_url'] != null;

    return GestureDetector(
      onTap: () => _showAlertDetail(a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ack ? AppTheme.borderSoft : color.withValues(alpha: 0.32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              Stack(
                children: [
                  Image.network(a['image_url'], height: 150, width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      height: 150, color: AppTheme.surfaceLight,
                      child: const Center(child: Icon(IconlyLight.image, color: AppTheme.textMuted)))),
                  Positioned(top: 10, left: 10, child: _badge(severity.toString().toUpperCase(), color)),
                  Positioned(top: 10, right: 10, child: _badge(_timeAgo(a['created_at']), Colors.black54)),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (!hasImage) ...[
                    _iconBox(ack ? IconlyBold.tick_square : IconlyBold.danger,
                      ack ? AppTheme.textMuted : color, color),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hasImage) _severityLabel(severity, color),
                      Text(a['title'] ?? 'Alert',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 14,
                          color: ack ? AppTheme.textMuted : AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      if ((a['message'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(a['message'],
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 12),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      if (!hasImage) ...[
                        const SizedBox(height: 4),
                        Text(_timeAgo(a['created_at']),
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ],
                  )),
                  if (!ack)
                    InkWell(
                      onTap: () async {
                        await CoreService.acknowledgeAlert(a['id']);
                        _loadData();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(IconlyBold.tick_square,
                          color: AppTheme.success, size: 18),
                      ),
                    )
                  else
                    const Icon(IconlyLight.arrow_right_2,
                      color: AppTheme.textMuted, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 40 * i), duration: 300.ms);
  }

  Widget _buildEventCard(Map<String, dynamic> e, int i) {
    final isStranger = e['result'] == 'stranger';
    final isFamily = e['result'] == 'family';
    final color = isStranger ? AppTheme.danger : (isFamily ? AppTheme.success : AppTheme.warning);
    final label = (e['result'] ?? 'unknown').toString().toUpperCase();
    final hasImage = e['image_url'] != null;
    final confidence = ((e['confidence'] ?? 0) * 100).toInt();

    return GestureDetector(
      onTap: () => _showEventDetail(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isStranger ? color.withValues(alpha: 0.32) : AppTheme.borderSoft),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              Stack(
                children: [
                  Image.network(e['image_url'], height: 160, width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c, er, s) => Container(
                      height: 160, color: AppTheme.surfaceLight,
                      child: const Center(child: Icon(IconlyLight.image, color: AppTheme.textMuted)))),
                  Positioned(top: 10, left: 10, child: _badge(label, color)),
                  Positioned(top: 10, right: 10, child: _badge(_timeAgo(e['created_at']), Colors.black54)),
                  Positioned(bottom: 10, left: 10, child: _badge('$confidence%', Colors.black54)),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (!hasImage) ...[
                    _iconBox(isStranger ? IconlyBold.danger : IconlyBold.profile, color, color),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hasImage) _severityLabel(label, color),
                      Text(
                        isStranger
                            ? 'Stranger detected'
                            : isFamily
                                ? 'Family: ${e['person_name'] ?? 'recognized'}'
                                : 'Unknown detection',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${e['device_name'] ?? e['device_id'] ?? 'Unknown'} · $confidence% confidence',
                        style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      if (!hasImage) ...[
                        const SizedBox(height: 4),
                        Text(_timeAgo(e['created_at']),
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ],
                  )),
                  const Icon(IconlyLight.arrow_right_2, color: AppTheme.textMuted, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 40 * i), duration: 300.ms);
  }

  void _showAlertDetail(Map<String, dynamic> a) {
    final ack = a['is_acknowledged'] == true;
    final severity = a['severity'] ?? 'medium';
    final color = _severityColor(severity);

    _showDetailSheet(
      children: [
        _chipRow([
          _chip(severity.toString().toUpperCase(), color),
          _chip(ack ? 'Acknowledged' : 'Pending', ack ? AppTheme.success : AppTheme.warning),
        ], _timeAgo(a['created_at'])),
        const SizedBox(height: 18),
        Text(a['title'] ?? 'Alert',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        if ((a['message'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(a['message'],
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSecondary, fontSize: 15, height: 1.5)),
        ],
        if (a['image_url'] != null) ...[
          const SizedBox(height: 16),
          _sectionLabel('Detection Snapshot'),
          const SizedBox(height: 8),
          _imagePreview(a['image_url']),
        ],
        const SizedBox(height: 16),
        _metadataBox({
          'Time': _fullTime(a['created_at']),
          if (a['event_id'] != null) 'Event ID': '#${a['event_id']}',
          if (ack) 'Acknowledged by': a['acknowledged_by_username'] ?? '—',
          if (ack) 'Acknowledged at': _fullTime(a['acknowledged_at']),
        }),
        if (!ack) ...[
          const SizedBox(height: 20),
          _ackButton(a['id']),
        ],
      ],
    );
  }

  void _showEventDetail(Map<String, dynamic> e) {
    final isStranger = e['result'] == 'stranger';
    final isFamily = e['result'] == 'family';
    final color = isStranger ? AppTheme.danger : (isFamily ? AppTheme.success : AppTheme.warning);
    final confidence = ((e['confidence'] ?? 0) * 100).toInt();

    _showDetailSheet(
      children: [
        _chipRow([
          _chip((e['result'] ?? 'unknown').toString().toUpperCase(), color),
          _chip('$confidence%', AppTheme.info),
        ], _timeAgo(e['created_at'])),
        const SizedBox(height: 18),
        Text(
          isStranger ? 'Stranger Detected' : isFamily ? 'Family Member: ${e['person_name'] ?? ''}' : 'Unknown Person',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        const SizedBox(height: 4),
        Text('From ${e['device_name'] ?? e['device_id']}',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 15)),
        if (e['image_url'] != null) ...[
          const SizedBox(height: 16),
          _sectionLabel('Captured Image'),
          const SizedBox(height: 8),
          _imagePreview(e['image_url']),
        ],
        const SizedBox(height: 16),
        _metadataBox({
          'Time': _fullTime(e['created_at']),
          'Device': e['device_name'] ?? e['device_id'] ?? '—',
          'Confidence': '$confidence%',
          if (e['person_name']?.isNotEmpty == true) 'Person': e['person_name'],
        }),
      ],
    );
  }

  void _showDetailSheet({required List<Widget> children}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              ...children,
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState({required IconData icon, required Color color, required String title, required String subtitle}) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 84, height: 84,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, size: 40, color: color),
      ),
      const SizedBox(height: 18),
      Text(title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
      const SizedBox(height: 4),
      Text(subtitle,
        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textMuted)),
    ]));
  }

  Widget _badge(String text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
    child: Text(text,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
  );

  Widget _iconBox(IconData icon, Color iconColor, Color bgColor) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      color: bgColor.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12)),
    child: Icon(icon, color: iconColor, size: 22),
  );

  Widget _severityLabel(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    margin: const EdgeInsets.only(bottom: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(5)),
    child: Text(text,
      style: GoogleFonts.plusJakartaSans(
        color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
  );

  Widget _chipRow(List<Widget> chips, String time) => Row(children: [
    ...chips.map((c) => Padding(padding: const EdgeInsets.only(right: 8), child: c)),
    const Spacer(),
    Text(time,
      style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
  ]);

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(9)),
    child: Text(text,
      style: GoogleFonts.plusJakartaSans(
        color: color, fontSize: 11, fontWeight: FontWeight.w800)),
  );

  Widget _sectionLabel(String text) => Text(text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary));

  Widget _imagePreview(String url) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.network(url, width: double.infinity, fit: BoxFit.cover,
      loadingBuilder: (ctx, child, p) => p == null
          ? child
          : SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(
                color: AppTheme.primary,
                value: p.expectedTotalBytes != null
                    ? p.cumulativeBytesLoaded / p.expectedTotalBytes!
                    : null))),
      errorBuilder: (c, e, s) => SizedBox(
        height: 200,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(IconlyLight.image, color: AppTheme.textMuted, size: 32),
            const SizedBox(height: 8),
            Text('Image unavailable',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 13)),
          ]))),
    ),
  );

  Widget _metadataBox(Map<String, String> data) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(14)),
    child: Column(children: data.entries.map((e) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text(e.key,
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 13)),
        const Spacer(),
        Text(e.value,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    )).toList()),
  );

  Widget _ackButton(int id) => SizedBox(
    width: double.infinity, height: 54,
    child: ElevatedButton.icon(
      onPressed: () async {
        await CoreService.acknowledgeAlert(id);
        if (mounted) Navigator.pop(context);
        _loadData();
      },
      icon: const Icon(IconlyBold.tick_square, size: 20),
      label: Text('Acknowledge Alert',
        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800)),
      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
    ),
  );

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical': return AppTheme.danger;
      case 'high': return AppTheme.accent;
      case 'medium': return AppTheme.warning;
      case 'low': return AppTheme.info;
      default: return AppTheme.textMuted;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(dateStr).toLocal());
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  String _fullTime(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return '—'; }
  }
}
