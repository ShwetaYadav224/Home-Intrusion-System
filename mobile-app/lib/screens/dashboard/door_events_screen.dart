import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconly/iconly.dart';
import '../../config/theme.dart';
import '../../services/core_service.dart';

class DoorEventsScreen extends StatefulWidget {
  const DoorEventsScreen({super.key});

  @override
  State<DoorEventsScreen> createState() => _DoorEventsScreenState();
}

class _DoorEventsScreenState extends State<DoorEventsScreen> {
  List<dynamic> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final resp = await CoreService.getDoorEvents(limit: 50);
    if (mounted) {
      setState(() {
        if (resp.success) {
          _events = resp.data['door_events'] ?? [];
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(IconlyLight.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Door Activity',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800, letterSpacing: -0.3)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadEvents,
              color: AppTheme.primary,
              child: _events.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      itemCount: _events.length,
                      itemBuilder: (_, i) => _buildEventTile(_events[i], i),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(IconlyLight.lock,
              size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 18),
          Text('No door activity yet',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            )),
          const SizedBox(height: 4),
          Text('Activity will show up here',
            style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> e, int index) {
    final isOpen = e['status'] == 'open';
    final color = isOpen ? AppTheme.danger : AppTheme.success;
    final icon = isOpen ? IconlyBold.unlock : IconlyBold.lock;
    final time = DateTime.parse(e['created_at']).toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'Door Opened' : 'Door Closed',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: color,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sensor: ${e['device_name'] ?? e['device_id']}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${time.day}/${time.month}',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms).slideX(begin: 0.05);
  }
}
