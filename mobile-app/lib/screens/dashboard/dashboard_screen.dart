import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';

import '../../config/theme.dart';
import '../../services/core_service.dart';
import 'door_events_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    final resp = await CoreService.getDashboard();
    if (mounted) {
      setState(() {
        if (resp.success) {
          _stats = resp.data;
        } else {
          _stats = {
            'total_devices': 0, 'active_devices': 0,
            'total_events': 0, 'events_today': 0,
            'strangers_today': 0, 'family_today': 0,
            'known_persons': 0, 'total_alerts': 0,
            'unacknowledged_alerts': 0,
            'recent_events': [], 'recent_alerts': [],
            'security_mode': {'mode': 'disarmed'},
            '_error': resp.message,
          };
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _stats == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final mode = _stats!['security_mode']?['mode'] ?? 'disarmed';
    final events = (_stats!['recent_events'] as List?) ?? [];
    final alerts = (_stats!['recent_alerts'] as List?) ?? [];
    final hasError = _stats!['_error'] != null;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasError) ...[
              _errorBanner(_stats!['_error']),
              const SizedBox(height: 14),
            ],
            _buildSecurityBanner(mode)
                .animate().fadeIn(duration: 400.ms).slideY(begin: 0.03),
            const SizedBox(height: 18),
            _buildDoorStatusCard()
                .animate().fadeIn(delay: 60.ms, duration: 350.ms),
            const SizedBox(height: 22),
            _buildQuickStats()
                .animate().fadeIn(delay: 120.ms, duration: 350.ms),
            const SizedBox(height: 26),
            _sectionTitle("Today's Activity"),
            const SizedBox(height: 12),
            _buildTodayRow()
                .animate().fadeIn(delay: 180.ms, duration: 350.ms),
            const SizedBox(height: 26),
            if (alerts.isNotEmpty) ...[
              _sectionTitle('Active Alerts'),
              const SizedBox(height: 12),
              ...alerts.take(3).toList().asMap().entries.map((entry) =>
                _buildAlertTile(entry.value)
                    .animate().fadeIn(delay: Duration(milliseconds: 220 + entry.key * 60), duration: 300.ms)),
              const SizedBox(height: 22),
            ],
            if (events.isNotEmpty) ...[
              _sectionTitle('Recent Detections'),
              const SizedBox(height: 12),
              ...events.take(5).toList().asMap().entries.map((entry) =>
                _buildEventTile(entry.value)
                    .animate().fadeIn(delay: Duration(milliseconds: 260 + entry.key * 50), duration: 300.ms)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.warning.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      const Icon(IconlyLight.info_circle, color: AppTheme.warning, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(msg,
        style: GoogleFonts.plusJakartaSans(color: AppTheme.warning, fontSize: 12))),
    ]),
  );

  Widget _buildSecurityBanner(String mode) {
    final configs = <String, _ModeData>{
      'armed':    _ModeData(IconlyBold.shield_done, AppTheme.danger,   'Armed',    'System is fully armed'),
      'home':     _ModeData(IconlyBold.home,        AppTheme.warning,  'Home',     'Monitoring perimeter only'),
      'disarmed': _ModeData(IconlyLight.shield_fail, AppTheme.textMuted, 'Disarmed', 'System is off'),
    };
    final m = configs[mode] ?? configs['disarmed']!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            m.color.withValues(alpha: 0.14),
            m.color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: m.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: m.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(m.icon, color: m.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Security', style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(m.label, style: GoogleFonts.plusJakartaSans(
                fontSize: 22, fontWeight: FontWeight.w800, color: m.color, letterSpacing: -0.4)),
              Text(m.subtitle, style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textMuted, fontSize: 12)),
            ],
          )),
          PopupMenuButton<String>(
            icon: const Icon(IconlyLight.setting, color: AppTheme.textSecondary, size: 22),
            color: AppTheme.elevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (v) async {
              final resp = await CoreService.setSecurityMode(v);
              if (resp.success) _loadDashboard();
            },
            itemBuilder: (_) => [
              _modeMenuItem('armed', 'Armed', IconlyBold.shield_done, AppTheme.danger),
              _modeMenuItem('home', 'Home', IconlyBold.home, AppTheme.warning),
              _modeMenuItem('disarmed', 'Disarmed', IconlyLight.shield_fail, AppTheme.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _statPill('${_stats!['active_devices']}', 'Online', IconlyBold.video, AppTheme.cyanGlow, AppTheme.primary),
        const SizedBox(width: 10),
        _statPill('${_stats!['unacknowledged_alerts']}', 'Alerts', IconlyBold.notification,
          const LinearGradient(colors: [Color(0xFFF87171), Color(0xFFD946EF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          AppTheme.danger),
        const SizedBox(width: 10),
        _statPill('${_stats!['events_today']}', 'Events', IconlyBold.activity, AppTheme.primaryGradient, AppTheme.secondary),
        const SizedBox(width: 10),
        _statPill('${_stats!['known_persons']}', 'People', IconlyBold.profile,
          const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF22D3EE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          AppTheme.success),
      ],
    );
  }

  Widget _statPill(String value, String label, IconData icon, Gradient gradient, Color glow) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Column(
          children: [
            GlowChip(icon: icon, gradient: gradient, size: 38, iconSize: 18, radius: 12, glowColor: glow),
            const SizedBox(height: 10),
            Text(value, style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.3)),
            Text(label, style: GoogleFonts.plusJakartaSans(
              fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayRow() {
    return Row(
      children: [
        Expanded(child: _todayCard(
          '${_stats!['family_today']}', 'Family', IconlyBold.heart, AppTheme.success)),
        const SizedBox(width: 10),
        Expanded(child: _todayCard(
          '${_stats!['strangers_today']}', 'Strangers', IconlyBold.danger, AppTheme.danger)),
      ],
    );
  }

  Widget _todayCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.3)),
            Text(label, style: GoogleFonts.plusJakartaSans(
              fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          ]),
        ],
      ),
    );
  }

  Widget _buildAlertTile(Map<String, dynamic> a) {
    final severity = a['severity'] ?? 'medium';
    final colors = {'critical': AppTheme.danger, 'high': AppTheme.accent, 'medium': AppTheme.warning, 'low': AppTheme.info};
    final color = colors[severity] ?? AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11)),
            child: Icon(IconlyBold.danger, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['title'] ?? 'Alert', style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(a['message'] ?? '', style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7)),
            child: Text(severity.toUpperCase(), style: GoogleFonts.plusJakartaSans(
              color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> e) {
    final isStranger = e['result'] == 'stranger';
    final isFamily = e['result'] == 'family';
    final color = isStranger ? AppTheme.danger : (isFamily ? AppTheme.success : AppTheme.warning);
    final confidence = ((e['confidence'] ?? 0) * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isStranger ? color.withValues(alpha: 0.28) : AppTheme.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              image: e['image_url'] != null ? DecorationImage(
                image: NetworkImage(e['image_url']),
                fit: BoxFit.cover,
              ) : null,
            ),
            child: e['image_url'] == null
                ? Icon(isStranger ? IconlyBold.danger : IconlyBold.profile, color: color, size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isStranger ? 'Stranger' : (e['person_name']?.isNotEmpty == true ? e['person_name'] : 'Unknown'),
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13,
                color: isStranger ? AppTheme.danger : AppTheme.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              '${e['device_name'] ?? e['device_id'] ?? 'Unknown'} · $confidence%',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 11),
            ),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7)),
            child: Text((e['result'] ?? '').toString().toUpperCase(),
              style: GoogleFonts.plusJakartaSans(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildDoorStatusCard() {
    final doorStatus = _stats!['door_status'] ?? 'unknown';
    final lastChanged = _stats!['door_last_changed'];
    final doorEventsToday = _stats!['door_events_today'] ?? 0;

    final isOpen = doorStatus == 'open';
    final isClosed = doorStatus == 'closed';
    final color = isOpen ? AppTheme.danger : (isClosed ? AppTheme.success : AppTheme.textMuted);
    final icon = isOpen ? IconlyBold.unlock : (isClosed ? IconlyBold.lock : IconlyLight.lock);
    final label = isOpen ? 'Open' : (isClosed ? 'Closed' : 'Unknown');
    final subtitle = isOpen ? 'Door is currently open' : (isClosed ? 'Door is securely closed' : 'No sensor data yet');

    String timeAgo = '';
    if (lastChanged != null) {
      try {
        final dt = DateTime.parse(lastChanged);
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) {
          timeAgo = 'Just now';
        } else if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours}h ago';
        } else {
          timeAgo = '${diff.inDays}d ago';
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoorEventsScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Door Status', style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(label, style: GoogleFonts.plusJakartaSans(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.4)),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textMuted, fontSize: 12)),
              ],
            )),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (timeAgo.isNotEmpty)
                  Text(timeAgo, style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text('$doorEventsToday today', style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: GoogleFonts.plusJakartaSans(
    fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3));

  PopupMenuItem<String> _modeMenuItem(String value, String label, IconData icon, Color color) {
    return PopupMenuItem(value: value, child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
    ]));
  }
}

class _ModeData {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  const _ModeData(this.icon, this.color, this.label, this.subtitle);
}
