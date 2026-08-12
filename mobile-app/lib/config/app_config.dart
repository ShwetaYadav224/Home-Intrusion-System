class AppConfig {
  AppConfig._();

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://172.20.10.10:8001',
  );

  static const String apiBase = '$baseUrl/api/v1';
  static const String authBase = '$apiBase/auth';

  static const String appName = 'Home Security';
  static const String appVersion = '1.0.0';

  static Uri? get _baseUri => Uri.tryParse(baseUrl);

  static bool isBackendUrl(String rawUrl) {
    final baseUri = _baseUri;
    final uri = Uri.tryParse(rawUrl.trim());
    if (baseUri == null || uri == null || uri.host.isEmpty) {
      return false;
    }

    final basePort =
        baseUri.hasPort ? baseUri.port : (baseUri.scheme == 'https' ? 443 : 80);
    final uriPort = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

    return uri.scheme == baseUri.scheme &&
        uri.host == baseUri.host &&
        uriPort == basePort;
  }

  static bool isProtectedStreamLookupUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !isBackendUrl(rawUrl)) {
      return false;
    }

    return RegExp(r'^/api/v1/devices/\d+/stream/?$').hasMatch(uri.path);
  }

  static String normalizeCameraStreamUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final candidate = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) {
      return trimmed;
    }

    if (isBackendUrl(candidate)) {
      return uri.replace(fragment: null).toString();
    }

    if (uri.port == 81) {
      final path = uri.path.toLowerCase();
      String normalizedPath = uri.path;
      if (path.isEmpty ||
          path == '/' ||
          path == '/capture' ||
          path == '/status' ||
          path == '/stream/') {
        normalizedPath = '/stream';
      }
      return uri.replace(path: normalizedPath, fragment: null).toString();
    }

    return uri.replace(fragment: null).toString();
  }

  static String streamPathHint(String rawUrl) {
    if (isProtectedStreamLookupUrl(rawUrl)) {
      return 'Use the raw ESP32 URL like http://<camera-ip>:81/stream, not /api/v1/devices/.../stream/.';
    }
    if (isBackendUrl(rawUrl)) {
      return 'This points to the backend, not the ESP32 camera. Use the camera IP on port 81.';
    }
    return 'Use the ESP32 stream path in the form http://<camera-ip>:81/stream.';
  }
}
