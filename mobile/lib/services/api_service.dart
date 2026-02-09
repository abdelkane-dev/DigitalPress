import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  ApiService({required this.baseUrl});

  Future<http.Response> post(String path, Map body, {String? token}) {
    return http.post(Uri.parse('$baseUrl$path'),
        headers: _headers(token), body: json.encode(body));
  }

  Future<http.Response> get(String path, {String? token}) {
    return http.get(Uri.parse('$baseUrl$path'), headers: _headers(token));
  }

  Map<String, String> _headers(String? token) {
    final h = {'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }
}
