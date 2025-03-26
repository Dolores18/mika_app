// lib/services/ai_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../utils/logger.dart';
import 'package:http/http.dart' as http;

class AiService {
  final String baseUrl = 'https://language.3049589.xyz/api';

  // 创建一个流来处理AI解释
  Stream<String> explainWord(String word) async* {
    if (word.isEmpty) {
      log.w('空单词AI解释已被忽略');
      return;
    }

    log.i('AI解释查询: "$word"');

    try {
      final uri = Uri.parse('$baseUrl/ai/explain/$word?stream=true');
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';

      final response = await http.Client().send(request);
      final stream = response.stream.transform(utf8.decoder);

      // 使用广播流以便多个监听者
      final broadcastStream = stream.asBroadcastStream();

      // 处理每个数据块
      await for (final data in broadcastStream) {
        final contents = _extractContent(data);
        if (contents.isNotEmpty) {
          for (final content in contents) {
            yield content;
          }
        }
      }
    } catch (e) {
      log.e('AI流处理异常', e);
      throw Exception('AI请求异常: $e');
    }
  }

  // 从Server-Sent Events格式中提取内容
  List<String> _extractContent(String data) {
    List<String> results = [];
    final lines = data.split('\n');

    for (var line in lines) {
      if (line.startsWith('data: ')) {
        final eventData = line.substring(6);
        if (eventData != '[DONE]') {
          final processedContent = _processApiResponse(eventData);
          if (processedContent.isNotEmpty) {
            results.add(processedContent);
          }
        }
      }
    }

    return results;
  }

  // 处理API响应数据 (从现有代码移植)
  String _processApiResponse(String text) {
    log.v('处理API响应数据: 输入长度 ${text.length}');

    // 解码Unicode转义序列
    String decoded = _decodeUnicodeEscapes(text);

    try {
      // 简化JSON提取逻辑，减少正则表达式使用
      if (decoded.startsWith('{') && decoded.endsWith('}')) {
        log.v('尝试直接解析JSON对象');
        try {
          Map<String, dynamic> jsonData = json.decode(decoded);
          if (jsonData.containsKey('content')) {
            String content = jsonData['content'].toString();
            log.v('直接JSON解析成功: 内容长度 ${content.length}');
            return content;
          }
        } catch (e) {
          log.v(
            '直接JSON解析失败: ${e.toString().substring(0, min(50, e.toString().length))}',
          );
        }
      }

      // 尝试提取JSON内容 - 只在第一种方法失败时使用
      log.v('尝试使用正则表达式提取JSON');
      RegExp jsonPattern = RegExp(r'\{.*?\}');
      Iterable<Match> matches = jsonPattern.allMatches(decoded);
      log.v('找到 ${matches.length} 个JSON匹配');

      String result = '';
      for (Match match in matches) {
        try {
          Map<String, dynamic> jsonData = json.decode(match.group(0)!);
          if (jsonData.containsKey('content')) {
            result += jsonData['content'].toString();
          }
        } catch (e) {
          // 静默处理JSON解析错误
        }
      }

      if (result.isNotEmpty) {
        log.v('使用正则表达式提取成功: 内容长度 ${result.length}');
        return result;
      } else {
        log.v('使用正则表达式提取失败: 未找到有效内容');
      }
    } catch (e) {
      log.v(
        'JSON提取过程异常: ${e.toString().substring(0, min(50, e.toString().length))}',
      );
    }

    // 基本清理 - 如果JSON解析失败
    log.v('使用基本文本处理方法');
    decoded = decoded.replaceAll(RegExp(r'\{"content":\s*"'), '');
    decoded = decoded.replaceAll(RegExp(r'"\}\{"content":\s*"'), '');
    decoded = decoded.replaceAll(RegExp(r'"\}'), '');

    // 替换转义序列
    decoded = decoded.replaceAll('\\n', '\n');
    decoded = decoded.replaceAll('\\t', '\t');
    decoded = decoded.replaceAll('\\"', '"');
    decoded = decoded.replaceAll('\\\\', '\\');

    log.v('基本处理完成: 输出长度 ${decoded.trim().length}');
    return decoded.trim();
  }

  // 解码Unicode转义序列 (从现有代码移植)
  String _decodeUnicodeEscapes(String text) {
    if (text.isEmpty) {
      log.v('解码Unicode转义序列: 输入为空');
      return text;
    }

    // 检查是否需要解码
    if (!text.contains('\\u')) {
      log.v('解码Unicode转义序列: 无需解码（无Unicode序列）');
      return text;
    }

    log.v(
      '解码Unicode转义序列: 输入长度 ${text.length}, 包含 ${RegExp(r'\\u').allMatches(text).length} 个Unicode序列',
    );

    // 替换所有Unicode转义序列为实际字符
    RegExp unicodeRegex = RegExp(r'\\u([0-9a-fA-F]{4})');
    String result = text.replaceAllMapped(unicodeRegex, (Match m) {
      try {
        int charCode = int.parse(m.group(1)!, radix: 16);
        return String.fromCharCode(charCode);
      } catch (e) {
        log.w('Unicode解码失败: ${m.group(0)}', e);
        return m.group(0)!;
      }
    });

    log.v('解码完成: 输出长度 ${result.length}');
    return result;
  }
}
