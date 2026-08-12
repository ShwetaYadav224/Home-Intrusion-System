import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iconly/iconly.dart';

import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../widgets/mjpeg_stream_view.dart';

class CameraLiveScreen extends StatefulWidget {
  final String deviceName;
  final String streamUrl;

  const CameraLiveScreen({
    super.key,
    required this.deviceName,
    required this.streamUrl,
  });

  @override
  State<CameraLiveScreen> createState() => _CameraLiveScreenState();
}

class _CameraLiveScreenState extends State<CameraLiveScreen> {
  bool _showControls = true;
  bool _captureInProgress = false;
  int _streamSession = 0;

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _restartStream() {
    setState(() => _streamSession++);
  }

  String _cameraEndpoint(String path) {
    final normalizedStreamUrl = AppConfig.normalizeCameraStreamUrl(
      widget.streamUrl,
    );
    final uri = Uri.tryParse(normalizedStreamUrl);
    if (uri == null || uri.host.isEmpty) {
      return normalizedStreamUrl;
    }
    return uri.replace(path: path, query: null, fragment: null).toString();
  }

  String _captureMessage(http.Response response) {
    if (response.body.isEmpty) {
      return 'Camera request failed with HTTP ${response.statusCode}';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        final result =
            decoded['data'] is Map<String, dynamic>
                ? decoded['data']['result']?.toString()
                : null;
        final confidence =
            decoded['data'] is Map<String, dynamic>
                ? decoded['data']['confidence']
                : null;

        if (result != null && result.isNotEmpty) {
          final confidenceLabel =
              confidence is num
                  ? ' (${(confidence * 100).toStringAsFixed(0)}%)'
                  : '';
          return 'Capture sent: $result$confidenceLabel';
        }
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}

    return response.body;
  }

  Future<void> _triggerCapture() async {
    if (_captureInProgress) return;

    final captureUrl = _cameraEndpoint('/capture');
    if (AppConfig.isBackendUrl(captureUrl)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppConfig.streamPathHint(widget.streamUrl)),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(captureUrl);
    if (uri == null || uri.host.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid camera URL. Update the stream URL first.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _captureInProgress = true);

    final client = http.Client();
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 35));

      final success = response.statusCode >= 200 && response.statusCode < 300;
      final message = _captureMessage(response);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppTheme.success : AppTheme.danger,
        ),
      );

      if (success) _restartStream();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Capture request failed: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      client.close();
      if (mounted) {
        setState(() => _captureInProgress = false);
      }
    }
  }

  Widget _glassButton(
    IconData icon,
    VoidCallback? onTap, {
    bool loading = false,
  }) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child:
            loading
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : Icon(icon, color: Colors.white, size: 18),
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar:
          _showControls
              ? AppBar(
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                elevation: 0,
                leading: _glassButton(
                  IconlyLight.arrow_left,
                  () => Navigator.pop(context),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.deviceName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.success.withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'REC',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  _glassButton(
                    IconlyBold.camera,
                    _captureInProgress ? null : _triggerCapture,
                    loading: _captureInProgress,
                  ),
                  _glassButton(IconlyLight.arrow_down_circle, _restartStream),
                ],
              )
              : null,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MjpegStreamView(
              key: ValueKey('${widget.streamUrl}::$_streamSession'),
              streamUrl: widget.streamUrl,
              fit: BoxFit.contain,
              loadingBuilder:
                  () => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.surface.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Connecting to camera...',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.streamUrl,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 300.ms),
                  ),
              errorBuilder:
                  (error) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: const Icon(
                            IconlyBold.danger,
                            color: AppTheme.danger,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Camera Offline',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Could not connect to the camera stream',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            widget.streamUrl,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: _restartStream,
                          icon: const Icon(
                            IconlyLight.arrow_down_circle,
                            size: 18,
                          ),
                          label: const Text('Retry Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed:
                              _captureInProgress ? null : _triggerCapture,
                          icon:
                              _captureInProgress
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(IconlyBold.camera, size: 18),
                          label: Text(
                            _captureInProgress
                                ? 'Capturing...'
                                : 'Trigger Capture',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Go Back',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms),
                  ),
            ),
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        IconlyBold.activity,
                        color: AppTheme.success,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.streamUrl,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          'MJPEG',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.success,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0),
              ),
          ],
        ),
      ),
    );
  }
}
