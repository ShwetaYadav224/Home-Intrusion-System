import '../services/api_client.dart';

class CoreService {
  static Future<ApiResponse> getDashboard() async {
    return ApiClient.get('/dashboard/');
  }

  static Future<ApiResponse> getDevices() async {
    return ApiClient.get('/devices/');
  }

  static Future<ApiResponse> getDevice(int id) async {
    return ApiClient.get('/devices/$id/');
  }

  static Future<ApiResponse> addDevice({
    required String deviceId,
    String name = '',
    String location = '',
    String streamUrl = '',
  }) async {
    return ApiClient.post('/devices/', body: {
      'device_id': deviceId,
      'name': name,
      'location': location,
      'stream_url': streamUrl,
    });
  }

  static Future<ApiResponse> updateDevice(int id, {String? name, String? location, bool? isActive}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (location != null) body['location'] = location;
    if (isActive != null) body['is_active'] = isActive;
    return ApiClient.patch('/devices/$id/', body: body);
  }

  static Future<ApiResponse> deleteDevice(int id) async {
    return ApiClient.delete('/devices/$id/');
  }

  static Future<ApiResponse> getDeviceStreamUrl(int id) async {
    return ApiClient.get('/devices/$id/stream/');
  }

  static Future<ApiResponse> getEvents({String? result, String? device, int limit = 50}) async {
    final params = <String>[];
    if (result != null) params.add('result=$result');
    if (device != null) params.add('device=$device');
    params.add('limit=$limit');
    return ApiClient.get('/events/?${params.join('&')}');
  }

  static Future<ApiResponse> getEvent(int id) async {
    return ApiClient.get('/events/$id/');
  }

  static Future<ApiResponse> getKnownPersons() async {
    return ApiClient.get('/known-persons/');
  }

  static Future<ApiResponse> getKnownPerson(int id) async {
    return ApiClient.get('/known-persons/$id/');
  }

  static Future<ApiResponse> addKnownPerson({
    required String name,
    List<String>? imagesBase64,
    String? imageBase64,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (imagesBase64 != null) body['images'] = imagesBase64;
    if (imageBase64 != null) body['image'] = imageBase64;
    
    return ApiClient.post('/known-persons/', body: body);
  }

  static Future<ApiResponse> addPhotosToPerson({
    required int id,
    required List<String> imagesBase64,
  }) async {
    return ApiClient.post('/known-persons/$id/', body: {'images': imagesBase64});
  }

  static Future<ApiResponse> deleteKnownPerson(int id) async {
    return ApiClient.delete('/known-persons/$id/');
  }

  static Future<ApiResponse> deleteKnownPersonPhoto(int personId, String photoId) async {
    return ApiClient.delete('/known-persons/$personId/photos/$photoId/');
  }

  static Future<ApiResponse> getSecurityMode() async {
    return ApiClient.get('/security-mode/');
  }

  static Future<ApiResponse> setSecurityMode(String mode) async {
    return ApiClient.put('/security-mode/', body: {'mode': mode});
  }

  static Future<ApiResponse> getAlerts({String? severity, bool? acknowledged, int limit = 50}) async {
    final params = <String>[];
    if (severity != null) params.add('severity=$severity');
    if (acknowledged != null) params.add('acknowledged=${acknowledged ? 'true' : 'false'}');
    params.add('limit=$limit');
    return ApiClient.get('/alerts/?${params.join('&')}');
  }

  static Future<ApiResponse> acknowledgeAlert(int id) async {
    return ApiClient.post('/alerts/$id/');
  }

  static Future<ApiResponse> acknowledgeAllAlerts() async {
    return ApiClient.post('/alerts/acknowledge-all/');
  }

  static Future<ApiResponse> getActivityLog({int limit = 50}) async {
    return ApiClient.get('/activity/?limit=$limit');
  }

  static Future<ApiResponse> getDoorEvents({String? doorStatus, int limit = 50}) async {
    final params = <String>[];
    if (doorStatus != null) params.add('status=$doorStatus');
    params.add('limit=$limit');
    return ApiClient.get('/door-events/?${params.join('&')}');
  }
}
