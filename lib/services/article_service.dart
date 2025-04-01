import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import '../models/article.dart';
import '../models/vocabulary.dart';
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
    log.i('获取API基础URL: $_baseUrl');
    return _baseUrl;
  }

  // 获取文章HTML URL
  static String getArticleHtmlUrl(String articleId) {
    // 直接使用与getArticleHtmlContent相同的URL格式
    final int idNum = int.tryParse(articleId) ?? 1;
    String url = '$_baseUrl/articles/$idNum/html';
    log.i('获取文章HTML URL: $url');
    return url;
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
      final response = await http.get(
        Uri.parse('$_baseUrl/analysis/topics/list'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Content-Type': 'application/json; charset=utf-8',
        },
      ).timeout(_requestTimeout);

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

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Content-Type': 'application/json; charset=utf-8',
        },
      ).timeout(_requestTimeout);

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
      log.i('从缓存获取文章ID: $id');
      return _articleCache[id]!;
    }

    try {
      log.i('从API请求文章ID: $id，URL: ${getBaseUrl()}/articles/$id');
      final response =
          await http.get(Uri.parse('${getBaseUrl()}/articles/$id'));
      log.i('文章请求响应码: ${response.statusCode}, 长度: ${response.body.length}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        log.i('文章解析成功，ID: $id, 标题: ${data['title']}');
        final article = Article.fromJson(data);
        _articleCache[id] = article; // 缓存文章
        return article;
      } else {
        log.e('文章请求失败: ${response.statusCode}, 内容: ${response.body}');
        throw Exception('Failed to load article: ${response.statusCode}');
      }
    } catch (e) {
      log.e('获取文章失败: $e');
      rethrow;
    }
  }

  // 获取文章HTML内容
  Future<String> getArticleHtmlContent(String id) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/articles/$id/html'));
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception(
            'Failed to load article content: ${response.statusCode}');
      }
    } catch (e) {
      log.e('获取文章HTML内容失败: $e');
      rethrow;
    }
  }

  // 获取文章Markdown内容
  Future<String> getArticleMarkdownContent(String id) async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/articles/$id/markdown'));
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception(
            'Failed to load article content: ${response.statusCode}');
      }
    } catch (e) {
      log.e('获取文章Markdown内容失败: $e');
      rethrow;
    }
  }

  // 获取文章词汇列表
  Future<List<Vocabulary>> getArticleVocabulary(String id) async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/articles/$id/vocabulary'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Vocabulary.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load vocabulary: ${response.statusCode}');
      }
    } catch (e) {
      log.e('获取文章词汇列表失败: $e');
      rethrow;
    }
  }

  // 获取文章音频URL
  Future<String> getArticleAudioUrl(String id) async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/articles/$id/audio'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['url'] as String;
      } else {
        throw Exception('Failed to load audio URL: ${response.statusCode}');
      }
    } catch (e) {
      log.e('获取文章音频URL失败: $e');
      rethrow;
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
      final response = await http.get(
        Uri.parse('$_baseUrl/analysis/topics/list'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'Content-Type': 'application/json; charset=utf-8',
        },
      ).timeout(_requestTimeout);

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
