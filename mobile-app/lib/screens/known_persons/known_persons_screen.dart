import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../services/core_service.dart';

class KnownPersonsScreen extends StatefulWidget {
  const KnownPersonsScreen({super.key});

  @override
  State<KnownPersonsScreen> createState() => _KnownPersonsScreenState();
}

class _KnownPersonsScreenState extends State<KnownPersonsScreen> {
  List<dynamic> _persons = [];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    imageCache.clearLiveImages();
    imageCache.clear();
    imageCache.clearLiveImages();
    
    setState(() => _loading = true);
    final resp = await CoreService.getKnownPersons();
    if (resp.success && mounted) {
      setState(() {
        _persons = resp.data['persons'] ?? [];
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addPerson() async {
    final nameCtrl = TextEditingController();
    String? base64Image;
    File? pickedFile;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24, 20, 24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 20),

                  Text(
                    'Add Family Member',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20, fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Take or choose a clear photo of their face',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),

                  GestureDetector(
                    onTap: () async {
                      final source = await showDialog<ImageSource>(
                        context: ctx,
                        builder: (dCtx) => SimpleDialog(
                          backgroundColor: AppTheme.surfaceLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text('Choose Source',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                          ),
                          children: [
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(dCtx, ImageSource.camera),
                              child: Row(children: [
                                const Icon(Icons.camera_alt, color: AppTheme.primary),
                                const SizedBox(width: 12),
                                Text('Camera', style: GoogleFonts.plusJakartaSans()),
                              ]),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(dCtx, ImageSource.gallery),
                              child: Row(children: [
                                const Icon(Icons.photo_library, color: AppTheme.secondary),
                                const SizedBox(width: 12),
                                Text('Gallery', style: GoogleFonts.plusJakartaSans()),
                              ]),
                            ),
                          ],
                        ),
                      );
                      if (source == null) return;

                      final picked = await ImagePicker().pickImage(
                        source: source,
                        maxWidth: 800,
                        imageQuality: 85,
                      );
                      if (picked == null) return;

                      final file = File(picked.path);
                      final bytes = await file.readAsBytes();
                      setSheetState(() {
                        pickedFile = file;
                        base64Image = base64Encode(bytes);
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: pickedFile != null
                              ? AppTheme.primary.withValues(alpha: 0.4)
                              : AppTheme.border,
                          width: pickedFile != null ? 2 : 1,
                        ),
                        image: pickedFile != null
                            ? DecorationImage(
                                image: FileImage(pickedFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: pickedFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 52, height: 52,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.add_a_photo,
                                    color: AppTheme.primary, size: 24),
                                ),
                                const SizedBox(height: 12),
                                Text('Tap to pick a photo',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textSecondary, fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                          : Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                    onPressed: () => setSheetState(() {
                                      pickedFile = null;
                                      base64Image = null;
                                    }),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Person\'s Name',
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
                      hintText: 'e.g. Mom, Dad, John',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: (nameCtrl.text.trim().isEmpty || base64Image == null)
                          ? null
                          : () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.person_add, size: 20),
                      label: Text('Add Person',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || base64Image == null || nameCtrl.text.trim().isEmpty) return;

    setState(() => _adding = true);

    final resp = await CoreService.addKnownPerson(
      name: nameCtrl.text.trim(),
      imageBase64: base64Image!,
    );

    if (mounted) {
      setState(() => _adding = false);
      if (resp.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${nameCtrl.text.trim()}'),
            backgroundColor: AppTheme.success.withValues(alpha: 0.9),
          ),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp.message),
            backgroundColor: AppTheme.danger.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  Future<void> _deletePerson(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove $name?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete this person from the known faces database. The system will no longer recognize them.',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text('Remove',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final resp = await CoreService.deleteKnownPerson(id);
    if (resp.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $name'),
          backgroundColor: AppTheme.success.withValues(alpha: 0.9),
        ),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        else if (_persons.isEmpty)
          _buildEmptyState()
        else
          _buildGrid(),

        Positioned(
          right: 20, bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: _adding ? null : _addPerson,
            backgroundColor: AppTheme.primary,
            icon: _adding
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.person_add, color: Colors.white, size: 20),
            label: Text(
              _adding ? 'Adding...' : 'Add Person',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.family_restroom, color: AppTheme.primary, size: 32),
          ),
          const SizedBox(height: 16),
          Text('No family members yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text('Add people so the system can recognize them',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: AppTheme.textMuted,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildGrid() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        itemCount: _persons.length,
        itemBuilder: (_, i) {
          final p = _persons[i];
          final photoUrl = p['photo_url'];
          final imageSrc = photoUrl != null 
              ? '$photoUrl?t=${DateTime.now().millisecondsSinceEpoch}'
              : null;

          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: imageSrc != null
                      ? Image.network(
                          imageSrc,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _photoPlaceholder(p['name']),
                        )
                      : _photoPlaceholder(p['name']),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'] ?? 'Unknown',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            if (p['created_at'] != null)
                              Text(
                                'Added ${_formatDate(p['created_at'])}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, color: AppTheme.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                          color: AppTheme.danger.withValues(alpha: 0.7), size: 20),
                        onPressed: () => _deletePerson(p['id'], p['name'] ?? 'Unknown'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(
            delay: Duration(milliseconds: 60 * i),
            duration: 300.ms,
          );
        },
      ),
    );
  }

  Widget _photoPlaceholder(String? name) {
    return Container(
      color: AppTheme.surfaceLight,
      child: Center(
        child: Text(
          (name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32, fontWeight: FontWeight.w800,
            color: AppTheme.primary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'today';
      if (diff.inDays == 1) return 'yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
