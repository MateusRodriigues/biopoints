// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Para Uint8List no uploadAvatar
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';

import '../models/transaction_history_item.dart';
import '../models/giftback.dart';
import '../models/lembrete.dart';
import '../models/campanha.dart';
import '../models/produto.dart';
import '../models/unidade.dart';
import '../models/UserProfile.dart';
import '../models/voucher_display.dart';

class ApiService {
  final String baseUrl;
  final SharedPreferences sharedPreferences;

  ApiService({required this.baseUrl, required this.sharedPreferences});

  Future<String?> _getToken() async {
    return sharedPreferences.getString('jwt_token');
  }

  Future<Map<String, String>> _getHeaders(
      {bool includeToken = true, bool isFormData = false}) async {
    final headers = <String, String>{};
    if (!isFormData) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    headers['Accept'] = 'application/json';

    if (includeToken) {
      final token = await _getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        if (kDebugMode) {
          print(
              '[ApiService] Token nulo ou vazio ao tentar incluir no header para requisição autenticada.');
        }
      }
    }
    return headers;
  }

  Future<http.Response> get(String endpoint, {bool includeToken = true}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeToken: includeToken);
    if (kDebugMode) {
      print(
          '[ApiService] GET $url com Token: ${headers.containsKey('Authorization')}');
    }
    try {
      return await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      if (kDebugMode) {
        print('[ApiService] GET Erro em $url: $e');
      }
      rethrow;
    }
  }

  Future<http.Response> post(String endpoint,
      {dynamic body, bool includeToken = true}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeToken: includeToken);
    if (kDebugMode) {
      print(
          '[ApiService] POST $url com Token: ${headers.containsKey('Authorization')}, Body: $body');
    }
    try {
      return await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      if (kDebugMode) {
        print('[ApiService] POST Erro em $url: $e');
      }
      rethrow;
    }
  }

  Future<http.Response> put(String endpoint,
      {dynamic body, bool includeToken = true}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeToken: includeToken);
    if (kDebugMode) {
      print(
          '[ApiService] PUT $url com Token: ${headers.containsKey('Authorization')}, Body: $body');
    }
    try {
      return await http
          .put(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      if (kDebugMode) {
        print('[ApiService] PUT Erro em $url: $e');
      }
      rethrow;
    }
  }

  Future<http.Response> delete(String endpoint,
      {bool includeToken = true}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(includeToken: includeToken);
    if (kDebugMode) {
      print(
          '[ApiService] DELETE $url com Token: ${headers.containsKey('Authorization')}');
    }
    try {
      final request = http.Request('DELETE', url);
      request.headers.addAll(headers);
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      return await http.Response.fromStream(streamedResponse);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiService] DELETE Erro em $url: $e');
      }
      rethrow;
    }
  }

  void _handleHttpError(http.Response response, String actionDescription) {
    if (kDebugMode) {
      print(
          '[ApiService] Erro ${response.statusCode} ao $actionDescription: ${response.body}');
    }
  }

  // --- Auth ---
  Future<http.Response> login(String email, String password) {
    final body = jsonEncode({'Email': email, 'Senha': password});
    return post('/api/auth/login', body: body, includeToken: false);
  }

  Future<http.Response> registerUser(Map<String, dynamic> registrationData) {
    return post('/api/auth/register',
        body: jsonEncode(registrationData), includeToken: false);
  }

  Future<http.Response> checkFieldAvailability(String field, String value) {
    final body = jsonEncode({'fieldName': field, 'value': value});
    return post('/api/auth/check-field', body: body, includeToken: true);
  }

  Future<http.Response> forgotPassword(String email) {
    final body = jsonEncode({'email': email});
    return post('/api/auth/forgot-password', body: body, includeToken: false);
  }

  Future<http.Response> resetPassword(
      String email, String token, String newPassword, String confirmPassword) {
    final body = jsonEncode({
      'email': email,
      'token': token,
      'newPassword': newPassword,
      'confirmNewPassword': confirmPassword
    });
    return post('/api/auth/reset-password', body: body, includeToken: false);
  }

  // --- Profile ---
  Future<UserProfile> getUserProfile() async {
    final response = await get('/api/profile/me');
    if (response.statusCode == 200) {
      return UserProfile.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } else if (response.statusCode == 401) {
      throw Exception('Sessão expirada. Por favor, faça login novamente.');
    } else {
      _handleHttpError(response, 'buscar perfil do usuário');
      throw Exception(
          'Falha ao buscar perfil do usuário (${response.statusCode})');
    }
  }

  Future<http.Response> updateUserProfile(Map<String, dynamic> profileData) {
    return put('/api/profile/me', body: jsonEncode(profileData));
  }

  Future<http.Response> changePassword(String newPassword) {
    final body = jsonEncode({'newPassword': newPassword});
    return post('/api/profile/change-password', body: body);
  }

  Future<http.StreamedResponse> uploadAvatar({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token não encontrado para upload de avatar.");
    }

    var uri = Uri.parse('$baseUrl/api/profile/me/avatar');
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    String? fileExtension = fileName.split('.').last.toLowerCase();
    MediaType? mediaType;

    if (fileExtension == 'png') {
      mediaType = MediaType('image', 'png');
    } else if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
      mediaType = MediaType('image', 'jpeg');
    } else if (fileExtension == 'gif') {
      mediaType = MediaType('image', 'gif');
    } else if (fileExtension == 'webp') {
      mediaType = MediaType('image', 'webp');
    } else {
      mediaType = MediaType('application', 'octet-stream');
    }

    if (imageBytes.isEmpty) {
      throw Exception(
          "Os bytes da imagem estão vazios e não podem ser enviados.");
    }

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: fileName,
      contentType: mediaType,
    ));

    try {
      return await request.send().timeout(const Duration(seconds: 45));
    } catch (e) {
      if (kDebugMode) {
        print('[ApiService uploadAvatar] Erro no envio: $e');
      }
      rethrow;
    }
  }

  // --- Units/Farmácias ---
  Future<List<Unidade>> getAllPharmacies() async {
    final response = await get('/api/farmacias', includeToken: false);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body
          .map((dynamic item) => Unidade.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      _handleHttpError(response, 'buscar todas as farmácias');
      throw Exception(
          'Falha ao buscar todas as farmácias (${response.statusCode})');
    }
  }

  Future<List<Unidade>> getMyLinkedUnits() async {
    final response = await get('/api/Units/my-linked');
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body
          .map((dynamic item) => Unidade.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Sessão expirada. Por favor, faça login novamente.');
    } else {
      _handleHttpError(response, 'buscar suas unidades vinculadas');
      throw Exception(
          'Falha ao buscar suas unidades vinculadas (${response.statusCode})');
    }
  }

  Future<http.Response> linkUnitToUser(int unitId) {
    return post('/api/profile/me/units/$unitId', body: jsonEncode({}));
  }

  Future<http.Response> unlinkUnit(int unitId) {
    return post('/api/Units/$unitId/unlink', body: jsonEncode({}));
  }

  // --- Products ---
  Future<List<Produto>> getProducts({int? unitId}) async {
    String endpoint =
        unitId != null ? '/api/products/unit/$unitId' : '/api/products';
    final response = await get(endpoint);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body
          .map((dynamic item) => Produto.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Sessão expirada. Por favor, faça login novamente.');
    } else {
      _handleHttpError(response, 'buscar produtos');
      throw Exception('Falha ao buscar produtos (${response.statusCode})');
    }
  }

  // --- Vouchers ---
  Future<List<VoucherDisplay>> getMyVouchers() async {
    final response = await get('/api/vouchers/my');
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body
          .map((dynamic item) =>
              VoucherDisplay.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Sessão expirada. Por favor, faça login novamente.');
    } else {
      _handleHttpError(response, 'buscar seus vouchers');
      throw Exception('Falha ao buscar seus vouchers (${response.statusCode})');
    }
  }

  Future<http.Response> redeemProductVoucher(int productId) {
    final body = jsonEncode({'productId': productId});
    return post('/api/vouchers/redeem', body: body);
  }

  Future<http.Response> redeemCampaignVoucher(int campaignId) {
    final body = jsonEncode({'campaignId': campaignId});
    return post('/api/vouchers/redeem-campaign', body: body);
  }

  Future<http.Response> checkPendingVouchers(int unitId) async {
    return get('/api/vouchers/check-pending?unitId=$unitId');
  }

  // --- Campanhas ---
  Future<List<Campanha>> getMinhasCampanhas() async {
    final response = await get('/api/Campanhas/my');
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body
          .map(
              (dynamic item) => Campanha.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Sessão expirada. Por favor, faça login novamente.');
    } else {
      _handleHttpError(response, 'buscar suas campanhas');
      throw Exception(
          'Falha ao buscar suas campanhas (${response.statusCode})');
    }
  }

  // --- Lembretes ---
  Future<List<Lembrete>> getMyLembretes() async {
    final response = await get('/api/lembretes/my');
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body
          .map(
              (dynamic item) => Lembrete.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Sessão expirada. Por favor, faça login novamente.');
    } else {
      _handleHttpError(response, 'buscar seus lembretes');
      throw Exception(
          'Falha ao buscar seus lembretes (${response.statusCode})');
    }
  }

  Future<http.Response> updateLembreteStatus(
      int lembreteId, String novoStatus) {
    final body = jsonEncode({'novoStatus': novoStatus});
    return put('/api/lembretes/$lembreteId/status', body: body);
  }

  Future<http.Response> deleteLembrete(int lembreteId) {
    return delete('/api/lembretes/$lembreteId');
  }

  // --- Histórico e Giftback ---
  Future<List<TransactionHistoryItem>> getTransactionHistory() async {
    final response = await get('/api/profile/history');
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body
          .map((dynamic item) =>
              TransactionHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Sessão expirada. Por favor, faça login novamente.');
    } else {
      _handleHttpError(response, 'buscar histórico de transações');
      throw Exception(
          'Falha ao buscar histórico de transações (${response.statusCode})');
    }
  }

  Future<List<Giftback>> getMyGiftbacks() async {
    final response = await get('/api/giftback/my');
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body
          .map(
              (dynamic item) => Giftback.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Sessão expirada. Por favor, faça login novamente.');
    } else {
      _handleHttpError(response, 'buscar seus giftbacks');
      throw Exception(
          'Falha ao buscar seus giftbacks (${response.statusCode})');
    }
  }

  // --- NOVO MÉTODO ADICIONADO ---
  Future<double> getTotalGiftbackValue() async {
    final response = await get('/api/giftback/my/total');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // A API retorna um objeto {"totalValue": 50.00}. Precisamos extrair o valor.
      final value = data['totalValue'];
      if (value is num) {
        return value.toDouble();
      }
      return 0.0;
    } else {
      _handleHttpError(response, 'buscar o valor total de giftbacks');
      throw Exception(
          'Falha ao buscar o total de giftbacks (${response.statusCode})');
    }
  }
}
