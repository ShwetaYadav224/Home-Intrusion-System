import '../services/api_client.dart';

class AuthService {
  static Future<ApiResponse> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String firstName = '',
    String lastName = '',
    String phone = '',
    String? householdName,
    String? inviteCode,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'email': email,
      'password': password,
      'password_confirm': passwordConfirm,
    };
    if (firstName.isNotEmpty) body['first_name'] = firstName;
    if (lastName.isNotEmpty) body['last_name'] = lastName;
    if (phone.isNotEmpty) body['phone'] = phone;
    if (householdName != null) body['household_name'] = householdName;
    if (inviteCode != null) body['invite_code'] = inviteCode;

    final resp = await ApiClient.post('/auth/register/', body: body, auth: false);
    if (resp.success && resp.data['tokens'] != null) {
      await ApiClient.saveTokens(
        resp.data['tokens']['access'],
        resp.data['tokens']['refresh'],
      );
    }
    return resp;
  }

  static Future<ApiResponse> login({
    required String identifier,
    required String password,
  }) async {
    final resp = await ApiClient.post(
      '/auth/login/',
      body: {'identifier': identifier, 'password': password},
      auth: false,
    );
    if (resp.success && resp.data['tokens'] != null) {
      await ApiClient.saveTokens(
        resp.data['tokens']['access'],
        resp.data['tokens']['refresh'],
      );
    }
    return resp;
  }

  static Future<ApiResponse> logout() async {
    final refresh = await ApiClient.refreshToken;
    final resp = await ApiClient.post(
      '/auth/logout/',
      body: {'refresh': refresh ?? ''},
    );
    await ApiClient.clearTokens();
    return resp;
  }

  static Future<ApiResponse> getProfile() async {
    return ApiClient.get('/auth/profile/');
  }

  static Future<ApiResponse> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (phone != null) body['phone'] = phone;
    return ApiClient.patch('/auth/profile/', body: body);
  }

  static Future<ApiResponse> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return ApiClient.post('/auth/change-password/', body: {
      'old_password': oldPassword,
      'new_password': newPassword,
      'new_password_confirm': confirmPassword,
    });
  }

  static Future<ApiResponse> updatePushToken(String token) async {
    return ApiClient.post('/auth/push-token/', body: {'push_token': token});
  }

  static Future<ApiResponse> getHousehold() async {
    return ApiClient.get('/auth/household/');
  }

  static Future<ApiResponse> updateHousehold({String? name, String? address}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (address != null) body['address'] = address;
    return ApiClient.patch('/auth/household/', body: body);
  }

  static Future<ApiResponse> getHouseholdMembers() async {
    return ApiClient.get('/auth/household/members/');
  }

  static Future<ApiResponse> removeMember(int userId) async {
    return ApiClient.post('/auth/household/members/$userId/remove/');
  }

  static Future<ApiResponse> forgotPassword(String email) async {
    return ApiClient.post('/auth/forgot-password/', body: {'email': email}, auth: false);
  }

  static Future<ApiResponse> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return ApiClient.post('/auth/reset-password/', body: {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
      'new_password_confirm': confirmPassword,
    }, auth: false);
  }

  static Future<ApiResponse> deleteAccount(String password) async {
    return ApiClient.post('/auth/delete-account/', body: {'password': password});
  }

  static Future<ApiResponse> verifyToken(String token) async {
    return ApiClient.post('/auth/verify-token/', body: {'token': token}, auth: false);
  }
}
