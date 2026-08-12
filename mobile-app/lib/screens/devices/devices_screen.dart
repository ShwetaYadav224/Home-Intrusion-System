import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';

import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../services/core_service.dart';
import 'camera_live_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<dynamic> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true);
    final resp = await CoreService.getDevices();
    if (resp.success && mounted) {
      setState(() {
        _devices = resp.data['devices'] ?? [];
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _showAddDeviceDialog() {
    final deviceIdCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final streamUrlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    IconlyBold.camera,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Add Device',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: deviceIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Device ID *',
                      hintText: 'e.g. strangerfinder-001',
                      prefixIcon: Icon(IconlyLight.scan, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Front Door Camera',
                      prefixIcon: Icon(IconlyLight.edit, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'e.g. Main Entrance',
                      prefixIcon: Icon(IconlyLight.location, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: streamUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Stream URL',
                      hintText: 'e.g. http://192.168.29.28:81/stream',
                      prefixIcon: Icon(IconlyLight.video, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (deviceIdCtrl.text.trim().isEmpty) return;
                  final resp = await CoreService.addDevice(
                    deviceId: deviceIdCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    location: locationCtrl.text.trim(),
                    streamUrl: streamUrlCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (resp.success) {
                    _loadDevices();
                  } else if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(resp.message)));
                  }
                },
                child: const Text('Add Device'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        color: AppTheme.primary,
        child:
            _devices.isEmpty
                ? ListView(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                    Center(
                      child: Column(
                        children: [
                          const GlowChip(
                            icon: IconlyBold.video,
                            size: 92,
                            iconSize: 42,
                            radius: 28,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No devices yet',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add your ESP32-CAM or sensor board',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textMuted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton.icon(
                            onPressed: _showAddDeviceDialog,
                            icon: const Icon(IconlyBold.plus, size: 18),
                            label: const Text('Add Device'),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                  ],
                )
                : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  itemCount: _devices.length,
                  itemBuilder: (_, i) => _buildDeviceCard(_devices[i], i),
                ),
      ),
      floatingActionButton:
          _devices.isNotEmpty
              ? FloatingActionButton.extended(
                onPressed: _showAddDeviceDialog,
                backgroundColor: AppTheme.primary,
                icon: const Icon(
                  IconlyBold.plus,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  'Device',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> d, int i) {
    final active = d['is_active'] == true;
    final hasStream = (d['stream_url'] ?? '').isNotEmpty;
    final name =
        d['name']?.isNotEmpty == true ? d['name'] : d['device_id'] ?? 'Unknown';
    final location = d['location'] ?? '';

    return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  active
                      ? AppTheme.success.withValues(alpha: 0.25)
                      : AppTheme.borderSoft,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasStream)
                GestureDetector(
                  onTap: () => _openLiveStream(d),
                  child: SizedBox(
                    height: 190,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.card, AppTheme.surface],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 18,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    IconlyBold.play,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Tap to watch live',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'LIVE',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              IconlyLight.arrow_right_2,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (active ? AppTheme.success : AppTheme.textMuted)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        hasStream ? IconlyBold.video : IconlyBold.activity,
                        color: active ? AppTheme.success : AppTheme.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (location.isNotEmpty) ...[
                                Icon(
                                  IconlyLight.location,
                                  size: 12,
                                  color: AppTheme.textMuted.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  location,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Text(
                                d['device_id'] ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textMuted.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: (active
                                    ? AppTheme.success
                                    : AppTheme.textMuted)
                                .withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color:
                                      active
                                          ? AppTheme.success
                                          : AppTheme.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                active ? 'Online' : 'Offline',
                                style: GoogleFonts.plusJakartaSans(
                                  color:
                                      active
                                          ? AppTheme.success
                                          : AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasStream) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _openLiveStream(d),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    IconlyBold.play,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Watch',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 60 * i), duration: 350.ms)
        .slideY(begin: 0.05, end: 0, duration: 350.ms);
  }

  Future<void> _openLiveStream(Map<String, dynamic> d) async {
    final fallbackUrl = AppConfig.normalizeCameraStreamUrl(
      (d['stream_url'] ?? '').toString(),
    );
    String streamUrl = fallbackUrl;
    final deviceId = d['id'];

    if (deviceId is int) {
      final resp = await CoreService.getDeviceStreamUrl(deviceId);
      if (resp.success) {
        streamUrl = AppConfig.normalizeCameraStreamUrl(
          (resp.data['stream_url'] ?? fallbackUrl).toString(),
        );
      } else if (fallbackUrl.isEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(resp.message)));
        return;
      }
    }

    if (streamUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No stream URL configured for this device.'),
        ),
      );
      return;
    }

    if (AppConfig.isBackendUrl(streamUrl)) {
      final canUseFallback =
          fallbackUrl.isNotEmpty && !AppConfig.isBackendUrl(fallbackUrl);
      if (canUseFallback) {
        streamUrl = fallbackUrl;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppConfig.streamPathHint(streamUrl))),
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CameraLiveScreen(
              deviceName:
                  d['name']?.isNotEmpty == true
                      ? d['name']
                      : d['device_id'] ?? 'Camera',
              streamUrl: streamUrl,
            ),
      ),
    );
  }
}
