import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import '../models/article.dart';
import '../utils/logger.dart';

class ArticleService {
  // 根据运行环境选择合适的地址
  // Android模拟器中使用10.0.2.2访问宿主机的localhost
  // iOS模拟器可以直接使用localhost或127.0.0.1
  //static const String _baseUrl = 'http://10.0.2.2:8000/api';
  //static const String _baseUrl = 'http://127.0.0.1:8000/api';
  static const String _baseUrl = 'http://47.79.39.75:7000/api';
  static final Map<String, Article> _articleCache = {};
  static const Duration _requestTimeout = Duration(seconds: 10);

  // 提供一个公共方法获取基础URL
  static String getBaseUrl() {
    return _baseUrl;
  }

  // 修复编码问题的方法
  String correctEncodingIssues(String text) {
    // 检测是否有常见的乱码模式
    if (text.contains('æ') ||
        text.contains('¿') ||
        text.contains('²') ||
        text.contains('å') ||
        text.contains('ä') ||
        text.contains('é')) {
      log.i('检测到可能的编码问题，尝试修正: $text');
      try {
        // 尝试将错误解码的UTF-8重新编码为UTF-8
        List<int> latinBytes = latin1.encode(text);
        String decoded = utf8.decode(latinBytes, allowMalformed: true);
        log.i('编码修正结果: $decoded');
        return decoded;
      } catch (e) {
        log.i('编码修正失败: $e');
      }
    }
    return text;
  }

  // 修复对象中的所有文本字段
  T fixEncodingInObject<T>(T obj) {
    if (obj is String) {
      return correctEncodingIssues(obj) as T;
    } else if (obj is List) {
      return obj.map((item) => fixEncodingInObject(item)).toList() as T;
    } else if (obj is Map) {
      Map result = {};
      obj.forEach((key, value) {
        result[key] = fixEncodingInObject(value);
      });
      return result as T;
    }
    return obj;
  }

  // 获取所有主题及其文章数量
  Future<List<Map<String, dynamic>>> getTopics() async {
    try {
      log.i('开始请求主题数据: $_baseUrl/analysis/topics/list');

      // 添加正确的请求头，指定UTF-8编码
      final response = await http
          .get(
            Uri.parse('$_baseUrl/analysis/topics/list'),
            headers: {
              'Accept': 'application/json; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
          )
          .timeout(_requestTimeout);

      log.i('主题数据响应状态: ${response.statusCode}');
      if (response.statusCode == 200) {
        // 使用UTF-8解码确保中文字符正确处理
        final String decodedBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = json.decode(decodedBody);

        log.i('成功获取主题数据: ${data.length} 项');

        // 准备固定的主题列表，初始化count为0
        final List<Map<String, dynamic>> result = [
          {'id': 1, 'topic': '政治', 'count': 0},
          {'id': 2, 'topic': '经济', 'count': 0},
          {'id': 3, 'topic': '科技', 'count': 0},
          {'id': 4, 'topic': '文化', 'count': 0},
          {'id': 5, 'topic': '其他', 'count': 0},
          {'id': 6, 'topic': '社会', 'count': 0},
        ];

        // 从API获取真实数量并更新固定主题
        final Map<String, int> topicCounts = {};
        for (var item in data) {
          if (item is Map &&
              item.containsKey('topic') &&
              item.containsKey('count')) {
            // 修正可能的编码问题
            String originalTopic = item['topic'] ?? '';
            String fixedTopic = correctEncodingIssues(originalTopic);
            topicCounts[fixedTopic] = item['count'] ?? 0;
          }
        }

        // 更新固定主题的count
        for (int i = 0; i < result.length; i++) {
          final String topic = result[i]['topic'];
          if (topicCounts.containsKey(topic)) {
            result[i]['count'] = topicCounts[topic];
          }
        }

        return result;
      } else {
        log.i('获取主题列表失败: HTTP ${response.statusCode}, 响应内容: ${response.body}');
        throw Exception('获取主题列表失败: ${response.statusCode}');
      }
    } catch (e) {
      log.i('获取主题列表出现异常: $e');
      // 提供模拟数据以便开发和测试，但确保数量更加真实
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('timeout') ||
          e.toString().contains('SocketException')) {
        log.i('使用模拟主题数据');

        // 获取各主题实际文章数量
        final Map<int, int> topicCounts = await _getTopicArticleCounts();

        return [
          {'id': 1, 'topic': '政治', 'count': topicCounts[1] ?? 0},
          {'id': 2, 'topic': '经济', 'count': topicCounts[2] ?? 0},
          {'id': 3, 'topic': '科技', 'count': topicCounts[3] ?? 0},
          {'id': 4, 'topic': '文化', 'count': topicCounts[4] ?? 0},
          {'id': 5, 'topic': '其他', 'count': topicCounts[5] ?? 0},
          {'id': 6, 'topic': '社会', 'count': topicCounts[6] ?? 0},
        ];
      }
      throw Exception('获取主题列表失败: $e');
    }
  }

  // 获取各主题实际文章数量的辅助方法
  Future<Map<int, int>> _getTopicArticleCounts() async {
    final Map<int, int> counts = {};

    try {
      // 遍历各主题ID，获取实际文章数量，范围从1到6
      for (int topicId = 1; topicId <= 6; topicId++) {
        try {
          final articles = await getArticlesByTopic(topicId.toString());
          counts[topicId] = articles.length;
        } catch (e) {
          log.i('获取主题 $topicId 文章数量失败: $e');
          // 失败时设置默认值
          counts[topicId] = 0;
        }
      }
    } catch (e) {
      log.i('获取主题文章数量失败: $e');
    }

    return counts;
  }

  // 根据主题获取文章列表 - 只使用主题ID
  Future<List<Map<String, dynamic>>> getArticlesByTopic(
    String topicOrId, {
    int page = 1, // 保留参数但不使用，避免破坏现有调用
  }) async {
    // 修正可能的编码问题
    String fixedTopicOrId = correctEncodingIssues(topicOrId);
    if (fixedTopicOrId != topicOrId) {
      log.i('主题名称修正: $topicOrId -> $fixedTopicOrId');
      topicOrId = fixedTopicOrId;
    }

    // 尝试解析为ID
    int? topicId = int.tryParse(topicOrId);

    // 如果不是数字ID，尝试将主题名映射到ID
    if (topicId == null) {
      // 简单的主题名到ID的映射
      final Map<String, int> topicNameToId = {
        '政治': 1,
        '经济': 2,
        '科技': 3,
        '文化': 4,
        '其他': 5,
        '社会': 6,
        // 添加乱码主题名的映射
        'æ¿æ²»': 1, // 政治
      };

      topicId = topicNameToId[topicOrId] ?? 1; // 默认使用政治主题ID
      log.i('非数字主题名: $topicOrId 已映射到主题ID: $topicId');
    }

    try {
      // 只使用ID路径，不再添加page参数
      final uri = Uri.parse('$_baseUrl/analysis/by_topic/$topicId');

      log.i('请求主题文章: $uri');
      log.i('使用主题ID: $topicId');

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
          )
          .timeout(_requestTimeout);

      log.i('主题文章响应状态: ${response.statusCode}');
      if (response.statusCode == 200) {
        // 使用UTF-8解码响应内容
        final String decodedBody = utf8.decode(response.bodyBytes);
        log.v('响应原始内容: ${response.body}');
        log.i('UTF-8解码后内容: $decodedBody');

        final data = json.decode(decodedBody);
        log.i('成功获取主题文章: ${data.length} 篇');

        // 检查解析后的数据结构
        if (data is List && data.isNotEmpty) {
          log.i('第一篇文章数据结构: ${data[0].keys.join(', ')}');
          if (data[0].containsKey('title')) {
            log.i('第一篇文章标题: ${data[0]['title']}');
          }
        }

        // 如果返回空数据，提供模拟数据
        if (data.isEmpty) {
          log.i('主题文章数据为空，使用模拟数据');
          return _getMockArticlesByTopicId(topicId.toString());
        }

        // 修正可能的编码问题
        List<Map<String, dynamic>> result = [];
        for (var item in data) {
          Map<String, dynamic> fixedItem = Map<String, dynamic>.from(item);

          // 修正文章标题
          if (fixedItem.containsKey('title') && fixedItem['title'] is String) {
            String originalTitle = fixedItem['title'];
            String fixedTitle = correctEncodingIssues(originalTitle);
            fixedItem['title'] = fixedTitle;

            if (originalTitle != fixedTitle) {
              log.i('文章标题修正: $originalTitle -> $fixedTitle');
            }
          }

          // 修正栏目标题
          if (fixedItem.containsKey('section') &&
              fixedItem['section'] is String) {
            String originalSection = fixedItem['section'];
            String fixedSection = correctEncodingIssues(originalSection);
            fixedItem['section'] = fixedSection;

            if (originalSection != fixedSection) {
              log.i('栏目标题修正: $originalSection -> $fixedSection');
            }
          }

          // 修正摘要
          if (fixedItem.containsKey('summary') &&
              fixedItem['summary'] is String) {
            String originalSummary = fixedItem['summary'];
            String fixedSummary = correctEncodingIssues(originalSummary);
            fixedItem['summary'] = fixedSummary;

            if (originalSummary != fixedSummary) {
              log.i('摘要修正: $originalSummary -> $fixedSummary');
            }
          }

          result.add(fixedItem);
        }

        return result;
      } else {
        log.i('获取主题文章失败: HTTP ${response.statusCode}, 响应内容: ${response.body}');
        return _getMockArticlesByTopicId(topicId.toString());
      }
    } catch (e) {
      log.i('获取主题文章出现异常: $e');
      return _getMockArticlesByTopicId(topicId.toString());
    }
  }

  // 根据主题ID获取模拟文章
  List<Map<String, dynamic>> _getMockArticlesByTopicId(String topicOrId) {
    int? topicId = int.tryParse(topicOrId);

    // 如果是ID，根据ID返回不同的模拟数据
    if (topicId != null) {
      log.i('使用主题ID[$topicId]获取模拟文章数据');

      switch (topicId) {
        case 1: // 政治
          return [
            {'id': 1, 'title': '全球政治格局分析'},
            {'id': 4, 'title': '欧盟新政策影响评估'},
            {'id': 7, 'title': '中东局势最新发展'},
          ];
        case 2: // 经济
          return [
            {'id': 2, 'title': '中央银行如何应对通胀？'},
            {'id': 5, 'title': '全球贸易趋势分析'},
            {'id': 8, 'title': '投资者如何应对市场波动'},
          ];
        case 3: // 科技
          return [
            {'id': 1, 'title': '全球芯片竞争加剧，台湾面临压力'},
            {'id': 6, 'title': 'AI发展的伦理考量'},
            {'id': 9, 'title': '量子计算最新进展'},
          ];
        case 4: // 文化
          return [
            {'id': 15, 'title': '全球文化交流趋势'},
            {'id': 16, 'title': '文化多样性的重要性'},
            {'id': 17, 'title': '东西方文化比较研究'},
          ];
        case 5: // 其他
          return [
            {'id': 3, 'title': '气候变化与南极冰川融化'},
            {'id': 10, 'title': '可再生能源市场发展'},
            {'id': 11, 'title': '全球健康挑战与对策'},
          ];
        case 6: // 社会
          return [
            {'id': 18, 'title': '社会问题分析'},
            {'id': 19, 'title': '社会发展趋势研究'},
            {'id': 20, 'title': '社会政策全球比较'},
          ];
        default:
          return [
            {'id': 12, 'title': '主题#$topicId 文章1'},
            {'id': 13, 'title': '主题#$topicId 文章2'},
            {'id': 14, 'title': '主题#$topicId 文章3'},
          ];
      }
    }
    // 如果是主题名，使用旧方法
    else {
      // 使用现有的文本匹配方法作为后备
      return _getMockArticlesByTopic(topicOrId);
    }
  }

  // 获取模拟主题文章数据 (按主题名称)
  List<Map<String, dynamic>> _getMockArticlesByTopic(String topic) {
    log.i('使用主题名[$topic]获取模拟文章数据');

    // 一些常用的主题名检查，兼容可能的乱码情况
    if (topic.contains('政') ||
        topic.contains('治') ||
        topic == 'æ¿æ²»' ||
        topic.contains('zhen') ||
        topic.toLowerCase().contains('polit')) {
      log.i('检测到"政治"相关主题，使用政治模拟数据');
      return [
        {'id': 1, 'title': '全球政治格局分析'},
        {'id': 4, 'title': '欧盟新政策影响评估'},
        {'id': 7, 'title': '中东局势最新发展'},
      ];
    }

    // 继续检查其他主题
    switch (topic) {
      case '经济':
      case 'economy':
      case 'æç»æµ':
        return [
          {'id': 2, 'title': '中央银行如何应对通胀？'},
          {'id': 5, 'title': '全球贸易趋势分析'},
          {'id': 8, 'title': '投资者如何应对市场波动'},
        ];
      case '科技':
      case 'tech':
      case 'technology':
      case 'æç§æ':
        return [
          {'id': 1, 'title': '全球芯片竞争加剧，台湾面临压力'},
          {'id': 6, 'title': 'AI发展的伦理考量'},
          {'id': 9, 'title': '量子计算最新进展'},
        ];
      case '社会':
      case 'society':
      case 'social':
        return [
          {'id': 18, 'title': '社会问题分析'},
          {'id': 19, 'title': '社会发展趋势研究'},
          {'id': 20, 'title': '社会政策全球比较'},
        ];
      case '环境':
      case 'environment':
      case 'æç¯å¢':
        return [
          {'id': 3, 'title': '气候变化与南极冰川融化'},
          {'id': 10, 'title': '可再生能源市场发展'},
          {'id': 11, 'title': '碳中和政策全球比较'},
        ];
      default:
        return [
          {'id': 12, 'title': '当前主题相关文章1'},
          {'id': 13, 'title': '当前主题相关文章2'},
          {'id': 14, 'title': '当前主题相关文章3'},
        ];
    }
  }

  // 获取文章详情
  Future<Article> getArticleById(String id) async {
    // 检查缓存
    if (_articleCache.containsKey(id)) {
      return _articleCache[id]!;
    }

    try {
      final uri = Uri.parse('$_baseUrl/articles/$id/with_analysis');
      log.i('开始请求文章详情: $uri');

      // 打印完整的请求头信息
      log.d(
        '请求头: {Accept: application/json; charset=utf-8, Content-Type: application/json; charset=utf-8}',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
          )
          .timeout(_requestTimeout);

      log.d('文章详情响应状态: ${response.statusCode}');

      // 打印详细的响应头信息
      log.d('响应头:');
      response.headers.forEach((key, value) {
        log.d('  $key: $value');
      });

      // 打印原始字节内容的十六进制表示
      log.v('响应正文原始字节 (前100字节, 十六进制): ');
      final bytes = response.bodyBytes;
      final hexList =
          bytes
              .take(100)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .toList();
      for (int i = 0; i < hexList.length; i += 16) {
        log.v('  ${hexList.skip(i).take(16).join(' ')}');
      }

      // 打印原始响应内容
      log.v('文章详情响应原始内容: ${response.body}');

      // 使用UTF-8解码并打印
      final String decodedBody = utf8.decode(response.bodyBytes);
      log.d('文章详情UTF-8解码后内容: $decodedBody');

      // 安全解析JSON
      if (decodedBody.isEmpty) {
        log.w('文章详情响应内容为空，使用模拟数据');
        return _getMockArticleById(id);
      }

      // 使用解码后的内容进行JSON解析
      final data = jsonDecode(decodedBody);

      // 检查响应格式 - 处理第一项作为article
      if (data == null) {
        log.w('文章详情响应解析为null，使用模拟数据');
        return _getMockArticleById(id);
      }

      // 处理API返回的数组格式（如果是数组）
      Map<String, dynamic> articleData;
      Map<String, dynamic>? analysisData;

      if (data is List && data.isNotEmpty) {
        log.d('API返回了数组格式的文章数据');
        articleData = Map<String, dynamic>.from(data[0]);

        // 检查是否有分析数据
        if (data.length > 1 && data[1] is Map) {
          analysisData = Map<String, dynamic>.from(data[1]);
          log.d('找到分析数据: ${analysisData.keys.join(', ')}');
        }
      } else if (data is Map && data.containsKey('article')) {
        // 如果返回了嵌套格式 {article: {...}, analysis: {...}}
        articleData = Map<String, dynamic>.from(data['article']);
        if (data.containsKey('analysis') && data['analysis'] != null) {
          analysisData = Map<String, dynamic>.from(data['analysis']);
        }
      } else {
        // 假设整个对象就是文章
        articleData = Map<String, dynamic>.from(data);
      }

      // 创建Article对象
      final article = Article(
        id:
            articleData['id'] is int
                ? articleData['id']
                : int.parse(articleData['id'].toString()),
        title: articleData['title'] ?? '未知标题',
        sectionId: articleData['section_id'] ?? 0,
        sectionTitle: articleData['section'] ?? '未知栏目',
        issueId: articleData['issue_id'] ?? 0,
        issueDate: articleData['issue_date'] ?? '未知日期',
        issueTitle: articleData['issue_title'] ?? '',
        order: articleData['order'] ?? 0,
        path: articleData['path'] ?? '',
        hasImages: articleData['has_images'] ?? false,
        audioUrl: articleData['audio_url'],
        analysis: null, // 稍后处理
      );

      log.i('加载文章详情: ID=${article.id}, 标题=${article.title}');

      // 处理analysis字段
      if (analysisData != null) {
        log.d('开始处理文章分析数据');
        try {
          // 先使用原始数据格式辅助调试
          final rawTopics = analysisData['topics'];
          final rawSummary = analysisData['summary'];

          if (rawTopics != null) {
            log.d('调试文章分析数据:');
            if (rawTopics is Map) {
              log.d('  - 主题: ${rawTopics['primary']}');
              if (rawTopics['keywords'] is List) {
                log.d('  - 关键词: ${(rawTopics['keywords'] as List).join(', ')}');
              }
            }
            if (rawSummary is Map && rawSummary['short'] != null) {
              log.d('  - 摘要: ${rawSummary['short']}');
            }
          }

          // 对分析数据进行UTF-8修正
          Map<String, dynamic> fixedAnalysis = {};

          // 手动处理topics字段
          if (rawTopics is Map) {
            Map<String, dynamic> fixedTopics = {};

            // 修正primary主题
            if (rawTopics['primary'] != null) {
              fixedTopics['primary'] = correctEncodingIssues(
                rawTopics['primary'].toString(),
              );
            } else {
              fixedTopics['primary'] = '政治'; // 默认主题
            }

            // 修正secondary主题列表
            if (rawTopics['secondary'] is List) {
              fixedTopics['secondary'] =
                  (rawTopics['secondary'] as List)
                      .map((topic) => correctEncodingIssues(topic.toString()))
                      .toList();
            } else {
              fixedTopics['secondary'] = [];
            }

            // 修正keywords关键词列表
            if (rawTopics['keywords'] is List) {
              fixedTopics['keywords'] =
                  (rawTopics['keywords'] as List)
                      .map(
                        (keyword) => correctEncodingIssues(keyword.toString()),
                      )
                      .toList();
            } else {
              fixedTopics['keywords'] = [];
            }

            fixedAnalysis['topics'] = fixedTopics;
          } else {
            // 创建默认topics
            fixedAnalysis['topics'] = {
              'primary': '政治',
              'secondary': [],
              'keywords': [],
            };
          }

          // 手动处理summary字段
          if (rawSummary is Map) {
            Map<String, dynamic> fixedSummary = {};

            // 修正short摘要
            if (rawSummary['short'] != null) {
              fixedSummary['short'] = correctEncodingIssues(
                rawSummary['short'].toString(),
              );
            } else {
              fixedSummary['short'] =
                  '这是一篇关于${fixedAnalysis['topics']['primary']}的文章...';
            }

            // 修正keyPoints关键点列表
            if (rawSummary['key_points'] is List) {
              fixedSummary['key_points'] =
                  (rawSummary['key_points'] as List)
                      .map((point) => correctEncodingIssues(point.toString()))
                      .toList();
            } else {
              fixedSummary['key_points'] = [];
            }

            fixedAnalysis['summary'] = fixedSummary;
          } else {
            // 创建默认summary
            fixedAnalysis['summary'] = {
              'short': '这是一篇关于${fixedAnalysis['topics']['primary']}的文章...',
              'key_points': [],
            };
          }

          // 设置其他分析字段
          fixedAnalysis['id'] = analysisData['id'] ?? article.id;
          fixedAnalysis['article_id'] =
              analysisData['article_id'] ?? article.id;
          fixedAnalysis['reading_time'] = analysisData['reading_time'] ?? 5;

          // 处理difficulty
          if (analysisData['difficulty'] is Map) {
            Map<String, dynamic> difficultyData = Map<String, dynamic>.from(
              analysisData['difficulty'],
            );
            fixedAnalysis['difficulty'] = {
              'level': correctEncodingIssues(
                difficultyData['level'] ?? 'B1-B2',
              ),
              'description': correctEncodingIssues(
                difficultyData['description'] ?? '适合中级英语学习者',
              ),
              'features':
                  difficultyData['features'] is List
                      ? (difficultyData['features'] as List)
                          .map(
                            (feature) =>
                                correctEncodingIssues(feature.toString()),
                          )
                          .toList()
                      : ['政经术语', '中等句式复杂度'],
            };
          } else {
            // 创建默认difficulty
            fixedAnalysis['difficulty'] = {
              'level': 'B1-B2',
              'description': '适合中级英语学习者',
              'features': ['政经术语', '中等句式复杂度'],
            };
          }

          // 处理vocabulary
          if (analysisData['vocabulary'] is List) {
            List<Map<String, dynamic>> fixedVocabulary = [];
            for (var vocab in analysisData['vocabulary']) {
              if (vocab is Map) {
                fixedVocabulary.add({
                  'word': correctEncodingIssues(vocab['word'] ?? ''),
                  'translation': correctEncodingIssues(
                    vocab['translation'] ?? '',
                  ),
                  'context': correctEncodingIssues(vocab['context'] ?? ''),
                  'example': correctEncodingIssues(vocab['example'] ?? ''),
                });
              }
            }
            fixedAnalysis['vocabulary'] = fixedVocabulary;
          } else {
            fixedAnalysis['vocabulary'] = [];
          }

          // 设置时间戳
          fixedAnalysis['created_at'] =
              analysisData['created_at'] ?? DateTime.now().toIso8601String();
          fixedAnalysis['updated_at'] =
              analysisData['updated_at'] ?? DateTime.now().toIso8601String();

          // 输出修正后的数据
          log.i('修正后的topics.primary: ${fixedAnalysis['topics']['primary']}');
          if (fixedAnalysis['topics']['keywords'] is List &&
              (fixedAnalysis['topics']['keywords'] as List).isNotEmpty) {
            log.i(
              '修正后的keywords: ${(fixedAnalysis['topics']['keywords'] as List).join(', ')}',
            );
          }
          log.i('修正后的summary.short: ${fixedAnalysis['summary']['short']}');

          // 创建ArticleAnalysis对象
          try {
            article.analysis = ArticleAnalysis(
              id: fixedAnalysis['id'],
              articleId: fixedAnalysis['article_id'],
              readingTime: fixedAnalysis['reading_time'],
              difficulty: Difficulty(
                level: fixedAnalysis['difficulty']['level'],
                description: fixedAnalysis['difficulty']['description'],
                features: List<String>.from(
                  fixedAnalysis['difficulty']['features'],
                ),
              ),
              topics: Topics(
                primary: fixedAnalysis['topics']['primary'],
                secondary: List<String>.from(
                  fixedAnalysis['topics']['secondary'],
                ),
                keywords: List<String>.from(
                  fixedAnalysis['topics']['keywords'],
                ),
              ),
              summary: Summary(
                short: fixedAnalysis['summary']['short'],
                keyPoints: List<String>.from(
                  fixedAnalysis['summary']['key_points'],
                ),
              ),
              vocabulary:
                  (fixedAnalysis['vocabulary'] as List)
                      .map(
                        (v) => Vocabulary(
                          word: v['word'],
                          translation: v['translation'],
                          context: v['context'],
                          example: v['example'],
                        ),
                      )
                      .toList(),
              createdAt: DateTime.parse(fixedAnalysis['created_at']),
              updatedAt: DateTime.parse(fixedAnalysis['updated_at']),
            );
          } catch (e) {
            log.i('创建ArticleAnalysis对象失败: $e');
            article.analysis = _createMockAnalysis(article.id);
          }
        } catch (e) {
          log.i('解析analysis字段出错: $e，使用模拟分析数据');
          article.analysis = _createMockAnalysis(article.id);
        }
      } else {
        log.i('API返回的analysis为null，使用模拟分析数据');
        article.analysis = _createMockAnalysis(article.id);
      }

      // 缓存文章
      _articleCache[id] = article;
      return article;
    } catch (e) {
      log.i('获取文章详情出现异常: $e');
      // 返回模拟文章数据
      return _getMockArticleById(id);
    }
  }

  // 创建模拟分析数据
  ArticleAnalysis _createMockAnalysis(int articleId) {
    return ArticleAnalysis(
      id: articleId,
      articleId: articleId,
      readingTime: 7,
      difficulty: Difficulty(
        level: 'B2-C1',
        description: '适合中高级英语学习者阅读',
        features: ['政经术语', '复杂句结构', '专业主题'],
      ),
      topics: Topics(
        primary: '时事',
        secondary: ['国际关系', '政治分析'],
        keywords: ['新闻', '时事', '国际'],
      ),
      summary: Summary(
        short: '这是一篇来自API的文章，但没有提供分析内容。这里是自动生成的摘要...',
        keyPoints: ['关键点1', '关键点2', '关键点3'],
      ),
      vocabulary: [
        Vocabulary(
          word: 'guarantee',
          translation: '保证，担保',
          context: 'security guarantee',
          example: 'The treaty provides security guarantees for the region.',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // 获取模拟文章详情
  Article _getMockArticleById(String id) {
    final int articleId = int.tryParse(id) ?? 1;
    log.i('使用模拟文章详情数据，ID: $articleId');

    // 根据不同ID返回不同的模拟文章
    switch (articleId) {
      case 1:
        return Article(
          id: 1,
          title: '全球芯片竞争加剧，台湾面临压力',
          sectionId: 1,
          sectionTitle: '科技专栏',
          issueId: 1,
          issueDate: '2024-03-20',
          issueTitle: '2024年第12期',
          order: 1,
          path: '/articles/1',
          hasImages: false,
          audioUrl: 'https://example.com/audio/1.mp3',
          analysis: ArticleAnalysis(
            id: 1,
            articleId: 1,
            readingTime: 8,
            difficulty: Difficulty(
              level: 'B1-B2',
              description: '适合中级英语学习者阅读',
              features: ['包含常见词汇', '句子结构适中', '主题贴近生活'],
            ),
            topics: Topics(
              primary: '科技',
              secondary: ['半导体', '全球竞争'],
              keywords: ['芯片', '台湾', '科技竞争'],
            ),
            summary: Summary(
              short: '随着全球芯片需求增长，台湾半导体产业面临来自多方的竞争压力...',
              keyPoints: ['全球芯片需求增长', '台湾半导体产业面临竞争', '多方压力增加'],
            ),
            vocabulary: [
              Vocabulary(
                word: 'semiconductor',
                translation: '半导体',
                context: 'semiconductor industry',
                example: 'The semiconductor industry is facing challenges.',
              ),
            ],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      case 2:
        return Article(
          id: 2,
          title: '中央银行如何应对通胀？',
          sectionId: 2,
          sectionTitle: '经济专栏',
          issueId: 2,
          issueDate: '2024-03-19',
          issueTitle: '2024年第11期',
          order: 1,
          path: '/articles/2',
          hasImages: false,
          audioUrl: 'https://example.com/audio/2.mp3',
          analysis: ArticleAnalysis(
            id: 2,
            articleId: 2,
            readingTime: 10,
            difficulty: Difficulty(
              level: 'C1-C2',
              description: '适合高级英语学习者阅读',
              features: ['专业术语较多', '复杂的经济概念', '深入的分析'],
            ),
            topics: Topics(
              primary: '经济',
              secondary: ['货币政策', '通货膨胀'],
              keywords: ['央行', '通胀', '货币政策'],
            ),
            summary: Summary(
              short: '面对持续上升的通胀压力，各国央行采取了不同的货币政策...',
              keyPoints: ['通胀压力上升', '各国央行政策差异', '货币政策调整'],
            ),
            vocabulary: [
              Vocabulary(
                word: 'inflation',
                translation: '通货膨胀',
                context: 'rising inflation',
                example:
                    'The central bank is concerned about rising inflation.',
              ),
            ],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      default:
        return Article(
          id: articleId,
          title: '模拟文章 #$articleId',
          sectionId: 1,
          sectionTitle: '模拟专栏',
          issueId: 1,
          issueDate: '2024-03-20',
          issueTitle: '2024年第12期',
          order: 1,
          path: '/articles/$articleId',
          hasImages: false,
          audioUrl: null,
          analysis: ArticleAnalysis(
            id: articleId,
            articleId: articleId,
            readingTime: 5,
            difficulty: Difficulty(
              level: 'B1-B2',
              description: '适合中级英语学习者阅读',
              features: ['常见词汇', '简单句式', '通用话题'],
            ),
            topics: Topics(
              primary: '综合',
              secondary: ['模拟主题'],
              keywords: ['模拟', '测试'],
            ),
            summary: Summary(
              short: '这是一篇模拟文章，用于测试应用功能...',
              keyPoints: ['模拟数据', '测试功能', '离线使用'],
            ),
            vocabulary: [
              Vocabulary(
                word: 'sample',
                translation: '样本',
                context: 'sample article',
                example: 'This is a sample article for testing.',
              ),
            ],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    }
  }

  // 清除缓存
  void clearCache() {
    _articleCache.clear();
  }

  // 获取所有分类
  Future<List<Category>> getCategories() async {
    try {
      // 使用主题API替代分类API
      log.i('开始请求分类数据: $_baseUrl/analysis/topics/list');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/analysis/topics/list'),
            headers: {
              'Accept': 'application/json; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
          )
          .timeout(_requestTimeout);

      log.i('分类数据响应状态: ${response.statusCode}');
      if (response.statusCode == 200) {
        // 使用UTF-8解码响应内容
        final String decodedBody = utf8.decode(response.bodyBytes);
        log.i('分类数据原始响应内容: ${response.body}');
        log.i('分类数据UTF-8解码后内容: $decodedBody');

        final List<dynamic> data = json.decode(decodedBody);

        // 检查解析后的数据
        if (data.isNotEmpty) {
          log.i('第一个分类数据: ${data[0]}');
          if (data[0] is Map && data[0].containsKey('topic')) {
            log.i('第一个分类主题名: ${data[0]['topic']}');
          }
        }

        // 将主题数据转换为分类格式并修正可能的编码问题
        List<Category> categories = [];
        for (var json in data) {
          // 修正主题名称
          String originalTopic = json['topic'] ?? '';
          String fixedTopic = correctEncodingIssues(originalTopic);

          if (originalTopic != fixedTopic) {
            log.i('分类名称修正: $originalTopic -> $fixedTopic');
          }

          categories.add(
            Category(
              id: json['id'].toString(),
              name: fixedTopic,
              count: json['count'] ?? 0,
            ),
          );
        }

        return categories;
      } else {
        log.i('获取分类列表失败: HTTP ${response.statusCode}, 响应内容: ${response.body}');
        throw Exception('获取分类列表失败: ${response.statusCode}');
      }
    } catch (e) {
      log.i('获取分类列表出现异常: $e');
      // 当连接出现问题时，提供模拟数据
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('timeout') ||
          e.toString().contains('SocketException')) {
        log.i('使用模拟分类数据');
        return [
          Category(id: '1', name: '政治', count: 15),
          Category(id: '2', name: '经济', count: 23),
          Category(id: '3', name: '科技', count: 18),
          Category(id: '4', name: '文化', count: 12),
          Category(id: '5', name: '其他', count: 10),
        ];
      }
      throw Exception('获取分类列表失败: $e');
    }
  }

  // 获取文章ID列表
  Future<ArticleListResponse> getArticleIds({
    int page = 1,
    int pageSize = 10,
    String? categoryId,
    String? source,
    String? difficulty,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (categoryId != null) 'category_id': categoryId,
        if (source != null) 'source': source,
        if (difficulty != null) 'difficulty': difficulty,
      };

      final uri = Uri.parse(
        '$_baseUrl/articles/ids',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Content-Type': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ArticleListResponse(
          ids: List<String>.from(data['ids']),
          total: data['total'],
          hasMore: data['has_more'],
        );
      } else {
        throw Exception('获取文章ID列表失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取文章ID列表失败: $e');
    }
  }

  // 根据ID列表获取文章详情
  Future<List<Article>> getArticlesByIds(List<String> ids) async {
    try {
      final articles = await Future.wait(ids.map((id) => getArticleById(id)));
      return articles;
    } catch (e) {
      throw Exception('获取文章详情失败: $e');
    }
  }

  // 获取文章HTML内容
  Future<String> getArticleHtmlContent(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/articles/$id/html');
      log.i('开始请求文章HTML内容: $uri');

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'text/html; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
          )
          .timeout(_requestTimeout);

      log.i('文章HTML内容响应状态: ${response.statusCode}');
      if (response.statusCode == 200) {
        // 使用UTF-8解码确保中文字符正确处理
        return utf8.decode(response.bodyBytes);
      } else {
        log.i(
          '获取文章HTML内容失败: HTTP ${response.statusCode}, 响应内容: ${response.body}',
        );
        throw Exception('获取文章HTML内容失败: ${response.statusCode}');
      }
    } catch (e) {
      log.i('获取文章HTML内容出现异常: $e');
      // 如果是连接问题，返回模拟HTML内容
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('timeout') ||
          e.toString().contains('SocketException')) {
        log.i('使用模拟HTML内容');
        return _getMockHtmlContent(id);
      }
      throw e;
    }
  }

  // 生成模拟HTML内容
  String _getMockHtmlContent(String id) {
    return '''
      <article>
        <h1>模拟文章内容 #$id</h1>
        <p>这是一篇模拟文章，真实内容需要在API可用时获取。</p>
        <h2>主要内容</h2>
        <p>这里是文章的主要内容部分，包含了详细的分析和论述。</p>
        <p>这篇文章分析了当前的全球经济形势、政治气候以及可能的未来发展趋势。</p>
        <blockquote>
          <p>经济学人杂志提供了对全球事件的深入分析和独特视角。</p>
        </blockquote>
        <h2>核心观点</h2>
        <ul>
          <li>观点一：全球合作对解决共同挑战至关重要</li>
          <li>观点二：技术创新正在改变传统行业格局</li>
          <li>观点三：气候变化需要紧急和协调的全球行动</li>
        </ul>
        <p>感谢您阅读这篇模拟文章，真实内容将在连接到服务器后显示。</p>
      </article>
    ''';
  }

  // 添加获取Markdown内容的方法
  Future<String> getArticleMarkdownContent(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/articles/$id/content');
      log.i('开始请求文章Markdown内容: $uri');

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json; charset=utf-8',
              'Content-Type': 'application/json; charset=utf-8',
            },
          )
          .timeout(_requestTimeout);

      log.i('文章Markdown内容响应状态: ${response.statusCode}');
      if (response.statusCode == 200) {
        // 解析JSON响应，获取message字段中的Markdown内容
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );

        if (data.containsKey('message') && data['message'] != null) {
          log.i('成功获取Markdown内容');
          return data['message'] as String;
        } else {
          log.w('响应中没有找到Markdown内容');
          return _getMockMarkdownContent(id);
        }
      } else {
        log.i(
          '获取文章Markdown内容失败: HTTP ${response.statusCode}, 响应内容: ${response.body}',
        );
        throw Exception('获取文章Markdown内容失败: ${response.statusCode}');
      }
    } catch (e) {
      log.i('获取文章Markdown内容出现异常: $e');
      // 如果是连接问题，返回模拟Markdown内容
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('timeout') ||
          e.toString().contains('SocketException')) {
        log.i('使用模拟Markdown内容');
        return _getMockMarkdownContent(id);
      }
      throw e;
    }
  }

  // 生成模拟Markdown内容
  String _getMockMarkdownContent(String id) {
    return '''
# 模拟文章内容 #$id

这是一篇模拟文章，真实内容需要在API可用时获取。

## 主要内容

这里是文章的主要内容部分，包含了详细的分析和论述。

这篇文章分析了当前的全球经济形势、政治气候以及可能的未来发展趋势。

> 经济学人杂志提供了对全球事件的深入分析和独特视角。

## 核心观点

- 观点一：全球合作对解决共同挑战至关重要
- 观点二：技术创新正在改变传统行业格局
- 观点三：气候变化需要紧急和协调的全球行动

感谢您阅读这篇模拟文章，真实内容将在连接到服务器后显示。
    ''';
  }
}

// 分类模型
class Category {
  final String id;
  final String name;
  final int count;

  Category({required this.id, required this.name, required this.count});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(id: json['id'], name: json['name'], count: json['count']);
  }
}

// 文章列表响应模型
class ArticleListResponse {
  final List<String> ids;
  final int total;
  final bool hasMore;

  ArticleListResponse({
    required this.ids,
    required this.total,
    required this.hasMore,
  });
}
