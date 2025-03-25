import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';

class ArticleService {
  static const String _baseUrl = 'http://127.0.0.1:8000/api';
  static final Map<String, Article> _articleCache = {};

  // 获取所有主题及其文章数量
  Future<List<Map<String, dynamic>>> getTopics() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analysis/topics/list'),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('获取主题列表失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取主题列表失败: $e');
    }
  }

  // 根据主题获取文章列表
  Future<List<Map<String, dynamic>>> getArticlesByTopic(String topic) async {
    try {
      final encodedTopic = Uri.encodeComponent(topic);
      final response = await http.get(
        Uri.parse('$_baseUrl/analysis/by_topic/$encodedTopic'),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('获取主题文章失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取主题文章失败: $e');
    }
  }

  // 获取文章详情
  Future<Article> getArticleById(String id) async {
    // 检查缓存
    if (_articleCache.containsKey(id)) {
      return _articleCache[id]!;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/articles/$id/with_analysis'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final article = Article.fromJson(data['article']);
        final analysis = ArticleAnalysis.fromJson(data['analysis']);
        article.analysis = analysis;

        // 缓存文章
        _articleCache[id] = article;
        return article;
      } else {
        throw Exception('获取文章详情失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取文章详情失败: $e');
    }
  }

  // 清除缓存
  void clearCache() {
    _articleCache.clear();
  }

  // 获取所有分类
  Future<List<Category>> getCategories() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/categories'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Category.fromJson(json)).toList();
      } else {
        throw Exception('获取分类列表失败: ${response.statusCode}');
      }
    } catch (e) {
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
      final response = await http.get(uri);

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
