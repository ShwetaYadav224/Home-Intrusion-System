import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'background_monitor_bridge.dart';

class ApiClient {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  static Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
    await BackgroundMonitorBridge.updateAuth(
      baseUrl: AppConfig.baseUrl,
      accessToken: access,
      refreshToken: refresh,
    );
  }

  static Future<String?> get accessToken async {
    final prefs = await SharedPreferences.getInstance();
    if (Platform.isAndroid) {
      await prefs.reload();
    }
    return prefs.getString(_accessKey);
  }

  static Future<String?> get refreshToken async {
    final prefs = await SharedPreferences.getInstance();
    if (Platform.isAndroid) {
      await prefs.reload();
    }
    return prefs.getString(_refreshKey);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await BackgroundMonitorBridge.clearAuth();
  }

  static Future<bool> get isLoggedIn async {
    final token = await accessToken;
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await accessToken;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<bool> _tryRefreshToken() async {
    final refresh = await refreshToken;
    if (refresh == null) return false;

    try {
      final resp = await http.post(
        Uri.parse('${AppConfig.authBase}/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['status'] == 'success') {
          await saveTokens(data['data']['access'], data['data']['refresh']);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<ApiResponse> get(String path, {bool auth = true}) async {
    return _request('GET', path, auth: auth);
  }

  static Future<ApiResponse> post(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    return _request('POST', path, body: body, auth: auth);
  }

  static Future<ApiResponse> patch(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    return _request('PATCH', path, body: body, auth: auth);
  }

  static Future<ApiResponse> put(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    return _request('PUT', path, body: body, auth: auth);
  }

  static Future<ApiResponse> delete(String path, {bool auth = true}) async {
    return _request('DELETE', path, auth: auth);
  }

  static Future<ApiResponse> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final url = Uri.parse('${AppConfig.apiBase}$path');
    final headers = await _headers(auth: auth);

    try {
      http.Response response;
      final encodedBody = body != null ? jsonEncode(body) : null;

      switch (method) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(url, headers: headers, body: encodedBody);
          break;
        case 'PATCH':
          response = await http.patch(url, headers: headers, body: encodedBody);
          break;
        case 'PUT':
          response = await http.put(url, headers: headers, body: encodedBody);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      if (response.statusCode == 401 && auth) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          return _request(method, path, body: body, auth: auth);
        }

        await clearTokens();
        return ApiResponse(
          statusCode: 401,
          success: false,
          message: 'Session expired. Please login again.',
          data: {},
        );
      }

      final decoded = jsonDecode(response.body);
      return ApiResponse(
        statusCode: response.statusCode,
        success: decoded['status'] == 'success',
        message: decoded['message'] ?? '',
        data: decoded['data'] ?? {},
      );
    } on SocketException {
      return ApiResponse(
        statusCode: 0,
        success: false,
        message: 'No internet connection',
        data: {},
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        success: false,
        message: 'Connection error: $e',
        data: {},
      );
    }
  }

  static Future<Map<String, dynamic>?> getWithoutInit(String path, {required String token}) async {
    final url = Uri.parse('${AppConfig.apiBase}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ [ApiClient] Background request error: $e');
      return null;
    }
  }

  static Future<ApiResponse> uploadMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required File file,
  }) async {
    final url = Uri.parse('${AppConfig.apiBase}$path');
    final token = await accessToken;

    try {
      final request = http.MultipartRequest('POST', url);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(response.body);

      return ApiResponse(
        statusCode: response.statusCode,
        success: decoded['status'] == 'success',
        message: decoded['message'] ?? '',
        data: decoded['data'] ?? {},
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        success: false,
        message: 'Upload error: $e',
        data: {},
      );
    }
  }
}

class ApiResponse {
  final int statusCode;
  final bool success;
  final String message;
  final dynamic data;

  ApiResponse({
    required this.statusCode,
    required this.success,
    required this.message,
    required this.data,
  });
}
