// lib/services/dictionary_service.dart
import 'dart:convert';
import 'dart:math';
import '../models/dictionary_result.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class DictionaryService {
  final String baseUrl = 'https://language.3049589.xyz/api';

  Future<DictionaryResult?> lookupWord(String word) async {
    if (word.isEmpty) {
      log.w('空单词查询已被忽略');
      return null;
    }

    log.i('字典查询: "$word"');

    try {
      final uri = Uri.parse('$baseUrl/stardict/$word');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        log.i('字典查询成功: $word');

        try {
          final json = jsonDecode(response.body);
          log.d(
            '字典返回结果: ${json.toString().substring(0, min(100, json.toString().length))}...',
          );

          return DictionaryResult.fromJson(json);
        } catch (e) {
          log.e('字典结果解析失败', e);
          throw Exception('解析结果出错: $e');
        }
      } else {
        log.w('字典查询失败: HTTP ${response.statusCode}');
        throw Exception('查询失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      log.e('字典查询异常', e);
      rethrow; // 向上传递异常，由调用者处理
    }
  }
}
