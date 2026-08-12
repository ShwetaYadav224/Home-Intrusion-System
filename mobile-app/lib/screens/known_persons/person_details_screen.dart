import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../services/core_service.dart';

class PersonDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> personData;

  const PersonDetailsScreen({super.key, required this.personData});

  @override
  State<PersonDetailsScreen> createState() => _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends State<PersonDetailsScreen> {
  late Map<String, dynamic> _person;
  bool _loadingEvents = true;
  List<dynamic> _memberEvents = [];

  @override
  void initState() {
    super.initState();
    _person = Map.from(widget.personData);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    final resp = await CoreService.getEvents(limit: 100);
    if (resp.success && mounted) {
      final allEvents = resp.data['events'] as List<dynamic>? ?? [];
      final name = _person['name'] ?? '';

      setState(() {
        _memberEvents = allEvents.where((e) {
          final msg = (e['message'] ?? '').toString();
          return msg.contains(name);
        }).toList();
        _loadingEvents = false;
      });
    } else if (mounted) {
      setState(() => _loadingEvents = false);
    }
  }

  Future<List<XFile>> _pickImages(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Select Photo Source',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 16),
            _sourceTile(ctx, IconlyBold.camera, 'Camera', 'Take a new photo', ImageSource.camera),
            const SizedBox(height: 10),
            _sourceTile(ctx, IconlyBold.image, 'Gallery', 'Choose from library', ImageSource.gallery),
          ],
        ),
      ),
    );

    if (source == null) return [];

    if (source == ImageSource.camera) {
      final img = await ImagePicker().pickImage(
        source: ImageSource.camera, maxWidth: 800, imageQuality: 85);
      return img != null ? [img] : [];
    } else {
      return await ImagePicker().pickMultiImage(maxWidth: 800, imageQuality: 85);
    }
  }

  Widget _sourceTile(BuildContext ctx, IconData icon, String title, String sub, ImageSource src) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pop(ctx, src),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(sub,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const Icon(IconlyLight.arrow_right_2,
              color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhotos() async {
    final picked = await _pickImages(context);
    if (picked.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    final base64s = <String>[];
    for (final p in picked) {
      base64s.add(base64Encode(await File(p.path).readAsBytes()));
    }

    final resp = await CoreService.addPhotosToPerson(id: _person['id'], imagesBase64: base64s);

    if (mounted) {
      Navigator.pop(context);
      if (resp.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${picked.length} photos'), backgroundColor: AppTheme.success),
        );
        if (resp.data != null) {
          setState(() {
            _person = Map<String, dynamic>.from(resp.data);
          });
        } else {
          _refreshDetails();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add photos'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _refreshDetails() async {
    final resp = await CoreService.getKnownPerson(_person['id']);
    if (resp.success && mounted) {
      setState(() {
        _person = Map<String, dynamic>.from(resp.data);
      });
    }
  }

  Future<void> _deleteMember() async {
    final name = _person['name'] ?? 'Unknown';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove Member?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to permanently remove "$name" and all associated biometrics?',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text('Remove',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    final photos = (_person['photos'] as List?)?.toList() ?? [];
    final ids = photos.map((p) => p['id']).toList();
    if (ids.isEmpty && _person['id'] != null) {
      ids.add(_person['id']);
    }

    bool success = true;
    for (final fid in ids) {
      final resp = await CoreService.deleteKnownPersonPhoto(_person['id'] ?? 0, fid.toString());
      if (!resp.success) success = false;
    }

    if (mounted) {
      Navigator.pop(context);
      if (success || ids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Member "$name" removed successfully'),
            backgroundColor: AppTheme.success.withValues(alpha: 0.9),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove member completely'),
            backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _deletePhoto(int index, dynamic photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Photo?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to remove this individual photo?',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      final resp = await CoreService.deleteKnownPersonPhoto(_person['id'], photo['id'].toString());
      if (resp.success && mounted) {
        setState(() {
          (_person['photos'] as List).removeAt(index);
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete photo'), backgroundColor: AppTheme.danger));
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day} ${_getMonth(dt.month)} ${dt.year}';
    } catch (_) {
      return '-- --';
    }
  }

  String _getMonth(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return m >= 1 && m <= 12 ? months[m-1] : '';
  }

  String _formatEventTime(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      final mo = _getMonth(d.month);
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '${d.day} $mo $h:$m';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _person['name'] ?? 'Unknown';
    final photos = (_person['photos'] as List?)?.toList() ?? [];
    final mainImg = photos.isNotEmpty ? photos[0]['url'] : null;
    final createdAt = _person['created_at'] != null ? _formatDate(_person['created_at']) : '-- --';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(IconlyLight.arrow_left, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Family',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 124,
                        height: 124,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: AppTheme.surfaceLight,
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.18),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          image: mainImg != null
                              ? DecorationImage(
                                  image: NetworkImage('$mainImg?t=${DateTime.now().millisecondsSinceEpoch}'),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: mainImg == null
                            ? Center(
                                child: Text(name[0].toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 50,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary.withValues(alpha: 0.55),
                                  )),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: -12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.4),
                                blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(IconlyBold.shield_done,
                                color: Colors.white, size: 12),
                              const SizedBox(width: 5),
                              Text('FAMILY',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            height: 1.1,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(IconlyBold.shield_done,
                              color: AppTheme.success, size: 14),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text('Verified identity',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _deleteMember,
                          icon: const Icon(IconlyLight.delete, size: 16),
                          label: Text(
                            'Remove',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.45)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 34),

              Row(
                children: [
                  Expanded(child: _infoCard(
                    IconlyBold.calendar, 'MEMBER SINCE', createdAt, AppTheme.info)),
                  const SizedBox(width: 12),
                  Expanded(child: _infoCard(
                    IconlyBold.shield_done, 'CONFIDENCE', 'High', AppTheme.success)),
                ],
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Biometric Gallery',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addPhotos,
                    icon: const Icon(IconlyBold.plus, size: 16, color: AppTheme.primary),
                    label: Text('Add',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (photos.isEmpty)
                _emptyBox('No biometric scans yet')
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    final imageSrc = photo['url'] != null
                        ? '${photo['url']}?t=${DateTime.now().millisecondsSinceEpoch}'
                        : null;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderSoft),
                        color: AppTheme.surfaceLight,
                        image: imageSrc != null
                            ? DecorationImage(
                                image: NetworkImage(imageSrc), fit: BoxFit.cover)
                            : null,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned(
                            top: 6, right: 6,
                            child: GestureDetector(
                              onTap: () => _deletePhoto(index, photo),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black87, shape: BoxShape.circle),
                                child: const Icon(IconlyBold.close_square,
                                  color: Colors.white, size: 12),
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
              const SizedBox(height: 36),

              Text('Event History',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                )),
              const SizedBox(height: 14),
              if (_loadingEvents)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppTheme.primary)))
              else if (_memberEvents.isEmpty)
                _emptyBox('No detection logs available')
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _memberEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final e = _memberEvents[index];
                    final timeStr = e['timestamp'] != null ? _formatEventTime(e['timestamp']) : '';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderSoft),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(IconlyBold.shield_done,
                              color: AppTheme.success, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Identity Verified',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary)),
                                const SizedBox(height: 2),
                                Text('${e['device_name'] ?? 'Front Door'} Camera',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          Text(timeStr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted,
                            )),
                        ],
                      ),
                    );
                  },
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Text(label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                )),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            )),
        ],
      ),
    );
  }

  Widget _emptyBox(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderSoft),
    ),
    child: Center(
      child: Text(msg,
        style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted)),
    ),
  );
}
