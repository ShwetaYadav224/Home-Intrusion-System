import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class MjpegStreamView extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;
  final Widget Function()? loadingBuilder;
  final Widget Function(dynamic error)? errorBuilder;

  const MjpegStreamView({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.contain,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<MjpegStreamView> createState() => _MjpegStreamViewState();
}

class _MjpegStreamViewState extends State<MjpegStreamView> {
  static const Duration _connectTimeout = Duration(seconds: 8);

  Uint8List? _currentFrame;
  bool _hasError = false;
  String _errorMessage = '';
  bool _loading = true;
  StreamSubscription? _subscription;
  http.Client? _client;
  int _connectionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant MjpegStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      reconnect();
    }
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  void _disconnect() {
    _connectionGeneration++;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }

  void reconnect() {
    _disconnect();
    if (mounted) {
      setState(() {
        _hasError = false;
        _loading = true;
        _currentFrame = null;
      });
    }
    _connect();
  }

  Future<void> _connect() async {
    final streamUrl = AppConfig.normalizeCameraStreamUrl(widget.streamUrl);
    if (streamUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No stream URL configured';
          _loading = false;
        });
      }
      return;
    }

    if (AppConfig.isBackendUrl(streamUrl)) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = AppConfig.streamPathHint(streamUrl);
          _loading = false;
        });
      }
      return;
    }

    final generation = ++_connectionGeneration;

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      request.headers['Accept'] = 'multipart/x-mixed-replace,image/jpeg,*/*';
      final response = await _client!.send(request).timeout(_connectTimeout);

      if (!mounted || generation != _connectionGeneration) {
        return;
      }

      if (response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'HTTP ${response.statusCode}';
            _loading = false;
          });
        }
        return;
      }

      final contentType =
          (response.headers['content-type'] ?? '').toLowerCase();
      if (!contentType.contains('multipart/x-mixed-replace') &&
          !contentType.contains('image/jpeg')) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage =
                'Invalid stream endpoint ($contentType). Expected http://<camera-ip>:81/stream';
            _loading = false;
          });
        }
        return;
      }

      List<int> buffer = [];
      bool inJpeg = false;

      _subscription = response.stream.listen(
        (chunk) {
          if (!mounted || generation != _connectionGeneration) {
            return;
          }

          buffer.addAll(chunk);

          while (buffer.length > 2) {
            if (!inJpeg) {
              int startIdx = -1;
              for (int i = 0; i < buffer.length - 1; i++) {
                if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
                  startIdx = i;
                  break;
                }
              }

              if (startIdx == -1) {
                if (buffer.length > 1) {
                  buffer = buffer.sublist(buffer.length - 1);
                }
                break;
              }

              buffer = buffer.sublist(startIdx);
              inJpeg = true;
            }

            if (inJpeg) {
              int endIdx = -1;
              for (int i = 1; i < buffer.length - 1; i++) {
                if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
                  endIdx = i + 2;
                  break;
                }
              }

              if (endIdx == -1) {
                break;
              }

              final frame = Uint8List.fromList(buffer.sublist(0, endIdx));
              buffer = buffer.sublist(endIdx);
              inJpeg = false;

              if (mounted && frame.length > 100) {
                setState(() {
                  _currentFrame = frame;
                  _loading = false;
                  _hasError = false;
                  _errorMessage = '';
                });
              }
            }
          }
        },
        onError: (error) {
          if (mounted && generation == _connectionGeneration) {
            setState(() {
              _hasError = true;
              _errorMessage = error.toString();
              _loading = false;
            });
          }
        },
        onDone: () {
          if (mounted && generation == _connectionGeneration) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Stream ended';
              _loading = false;
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (mounted && generation == _connectionGeneration) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorBuilder?.call(_errorMessage) ??
          Center(
            child: Text(
              'Error: $_errorMessage',
              style: const TextStyle(color: Colors.red),
            ),
          );
    }

    if (_loading || _currentFrame == null) {
      return widget.loadingBuilder?.call() ??
          const Center(child: CircularProgressIndicator());
    }

    return Image.memory(
      _currentFrame!,
      fit: widget.fit,
      gaplessPlayback: true,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
