// lib/services/dictionary_service.dart
import 'dart:convert';
import 'dart:math';
import '../models/dictionary_result.dart';
import '../providers/word_lookup/word_lookup_state.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class DictionaryService {
  final String baseUrl = 'https://language.3049589.xyz/api';
  final String dictBaseUrl = 'https://dict.3049589.xyz';

  Future<Map<String, dynamic>> lookupWord(String word, SearchLanguage language) async {
    if (word.isEmpty) {
      log.w('空单词查询已被忽略');
      return {'result': null, 'htmlContent': null};
    }

    log.i('字典查询: "$word" (${language.displayName})');

    try {
      if (language == SearchLanguage.japanese) {
        return await _lookupJapaneseWord(word);
      } else {
        final result = await _lookupEnglishWord(word);
        return {'result': result, 'htmlContent': null};
      }
    } catch (e) {
      log.e('字典查询异常', e);
      rethrow;
    }
  }

  // 英语单词查询
  Future<DictionaryResult?> _lookupEnglishWord(String word) async {
    final uri = Uri.parse('$baseUrl/stardict/$word');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      log.i('英语字典查询成功: $word');

      try {
        final json = jsonDecode(response.body);
        log.d(
          '英语字典返回结果: ${json.toString().substring(0, min(100, json.toString().length))}...',
        );

        return DictionaryResult.fromJson(json);
      } catch (e) {
        log.e('英语字典结果解析失败', e);
        throw Exception('解析结果出错: $e');
      }
    } else {
      log.w('英语字典查询失败: HTTP ${response.statusCode}');
      throw Exception('查询失败: HTTP ${response.statusCode}');
    }
  }

  // 日语前缀搜索（用于实时搜索建议）
  Future<List<Map<String, dynamic>>> searchJapanesePrefix(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final prefixUri = Uri.parse('$dictBaseUrl/prefix-search');
      final prefixResponse = await http.post(
        prefixUri,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'query': query, 'request_id': 1}),
        encoding: utf8,
      );

      if (prefixResponse.statusCode == 200) {
        final responseBody = utf8.decode(prefixResponse.bodyBytes);
        final responseData = jsonDecode(responseBody);
        log.i('日语前缀搜索成功: $query, 返回${responseData['count']}个结果');
        
        // 解析返回的搜索建议
        if (responseData is Map && 
            responseData.containsKey('success') && 
            responseData['success'] == true &&
            responseData.containsKey('entries')) {
          
          final entries = responseData['entries'] as List;
          final suggestions = <Map<String, dynamic>>[];
          
          for (final entry in entries) {
            if (entry is Map<String, dynamic>) {
              // 检查必要字段是否存在
              if (entry.containsKey('headword') && entry['headword'] != null &&
                  entry.containsKey('kana_reading') && entry['kana_reading'] != null) {
                
                // 避免重复（基于headword）
                final headword = entry['headword'].toString();
                final exists = suggestions.any((s) => s['headword'] == headword);
                
                if (!exists) {
                  // 查询文本：优先kanji_writing，没有则用kana_reading
                  final kanjiWriting = entry['kanji_writing']?.toString() ?? '';
                  final kanaReading = entry['kana_reading'].toString();
                  final queryText = kanjiWriting.isNotEmpty ? kanjiWriting : kanaReading;
                  
                  suggestions.add({
                    'headword': headword,
                    'kana_reading': kanaReading,
                    'kanji_writing': kanjiWriting,
                    'query_text': queryText,        // 查询文本
                  });
                }
                
                // 限制建议数量
                if (suggestions.length >= 10) {
                  break;
                }
              }
            }
          }
          
          log.i('解析出${suggestions.length}个搜索建议');
          log.i('建议列表: $suggestions');
          return suggestions;
        } else {
          log.w('日语前缀搜索返回格式异常');
          return [];
        }
      } else {
        log.w('日语前缀搜索失败: HTTP ${prefixResponse.statusCode}');
        return [];
      }
    } catch (e) {
      log.e('日语前缀搜索异常', e);
      return [];
    }
  }

  // 日语单词查询
  Future<Map<String, dynamic>> _lookupJapaneseWord(String word) async {
    // 然后获取详细信息
    final detailUri = Uri.parse('$baseUrl/japanese/html/$word');
    final detailResponse = await http.get(detailUri);

    if (detailResponse.statusCode == 200) {
      log.i('日语字典查询成功: $word');

      // 返回完整的HTML内容和简化的DictionaryResult
      final htmlContent = detailResponse.body;
      final result = _parseJapaneseHtml(word, htmlContent);
      
      return {
        'result': result,
        'htmlContent': htmlContent,
      };
    } else {
      log.w('日语字典查询失败: HTTP ${detailResponse.statusCode}');
      throw Exception('查询失败: HTTP ${detailResponse.statusCode}');
    }
  }

  // 解析日语HTML内容
  DictionaryResult _parseJapaneseHtml(String word, String htmlContent) {
    // 简单的HTML解析，提取主要信息
    // 这里做基本的文本提取，实际项目中可能需要更复杂的HTML解析
    
    String cleanText = htmlContent
        .replaceAll(RegExp(r'<[^>]*>'), ' ') // 移除HTML标签
        .replaceAll(RegExp(r'\s+'), ' ') // 合并多个空格
        .trim();

    // 提取主要释义部分
    String definition = '';
    if (cleanText.contains('中心義')) {
      final startIndex = cleanText.indexOf('中心義');
      final endIndex = cleanText.indexOf('返回搜索', startIndex);
      if (endIndex > startIndex) {
        definition = cleanText.substring(startIndex, endIndex).trim();
      }
    }

    if (definition.isEmpty) {
      // 如果没找到中心義，尝试提取其他释义信息
      final lines = cleanText.split('\n');
      for (String line in lines) {
        if (line.contains('①') || line.contains('②') || line.contains('③')) {
          definition += '$line\n';
        }
      }
    }

    return DictionaryResult(
      word: word,
      phonetic: '', // 日语通常不需要音标
      definition: definition.isNotEmpty ? definition : '未找到释义',
      translation: '', // 日语词典通常直接提供日语释义
      tag: '日语词汇',
      exchange: '',
      collins: '',
      oxford: '',
    );
  }
}
