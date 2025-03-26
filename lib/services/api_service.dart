// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class ApiService {
  final String baseUrl = 'https://language.3049589.xyz/api';

  // 基础 GET 请求
  Future<http.Response> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl/$endpoint');
    log.d('API GET 请求: $uri');
    return await http.get(uri);
  }

  // 流式 GET 请求
  Future<http.StreamedResponse> getStream(String endpoint) async {
    final uri = Uri.parse('$baseUrl/$endpoint');
    log.d('API 流式请求: $uri');

    final request = http.Request('GET', uri);
    request.headers['Accept'] = 'text/event-stream';
    return await http.Client().send(request);
  }
}
