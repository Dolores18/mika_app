// 文章难度枚举
import '../utils/logger.dart';
import 'vocabulary.dart';
import 'dart:math'; // 引入math库

enum ArticleDifficulty {
  easy, // 初级
  medium, // 中级
  hard, // 高级
}

class Article {
  final int? id; // 文章ID，可能为null
  final String title; // 标题
  final int? sectionId; // 章节ID，可能为null
  final String? sectionTitle; // 章节标题
  final int? issueId; // 期号ID，可能为null
  final String? issueDate; // 发布日期
  final String? issueTitle; // 期号标题
  final int? order; // 排序，可能为null
  final String? path; // 文件路径
  final bool hasImages; // 是否有图片
  final String? audioUrl; // 音频URL
  final ArticleAnalysis? analysis;

  Article({
    this.id,
    required this.title,
    this.sectionId,
    this.sectionTitle,
    this.issueId,
    this.issueDate,
    this.issueTitle,
    this.order,
    this.path,
    required this.hasImages,
    this.audioUrl,
    this.analysis,
  });

  // 从JSON创建Article对象
  factory Article.fromJson(Map<String, dynamic> json) {
    try {
      log.i('正在解析文章JSON数据');

      // 确保标题字段存在
      if (json['title'] == null) {
        throw FormatException('文章缺少标题字段');
      }

      return Article(
        id: json['id'] != null ? json['id'] as int : null,
        title: json['title'] as String,
        sectionId:
            json['section_id'] != null ? json['section_id'] as int : null,
        sectionTitle: json['section'] as String?, // 允许为null
        issueId: json['issue_id'] != null ? json['issue_id'] as int : null,
        issueDate: json['issue_date'] as String?, // 允许为null
        issueTitle: json['issue_title'] as String?, // 允许为null
        order: json['order'] != null ? json['order'] as int : null,
        path: json['path'] as String?, // 允许为null
        hasImages: json['has_images'] != null
            ? json['has_images'] as bool
            : false, // 默认为false
        audioUrl: json['audio_url'] as String?,
        analysis: json['analysis'] != null
            ? ArticleAnalysis.fromJson(json['analysis'] as Map<String, dynamic>)
            : null,
      );
    } catch (e) {
      log.e('解析文章JSON数据失败: $e');
      log.e(
          '问题JSON: ${json.toString().substring(0, min(200, json.toString().length))}...');
      rethrow;
    }
  }

  // 将Article对象转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'section_id': sectionId,
      'section': sectionTitle,
      'issue_id': issueId,
      'issue_date': issueDate,
      'issue_title': issueTitle,
      'order': order,
      'path': path,
      'has_images': hasImages,
      'audio_url': audioUrl,
      'analysis': analysis?.toJson(),
    };
  }
}

// 文章分析模型
class ArticleAnalysis {
  final int id;
  final int articleId;
  final int readingTime;
  final Difficulty difficulty;
  final Topics topics;
  final Summary summary;
  final List<Vocabulary> vocabulary;
  final DateTime createdAt;
  final DateTime updatedAt;

  ArticleAnalysis({
    required this.id,
    required this.articleId,
    required this.readingTime,
    required this.difficulty,
    required this.topics,
    required this.summary,
    required this.vocabulary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ArticleAnalysis.fromJson(Map<String, dynamic> json) {
    try {
      return ArticleAnalysis(
        id: json['id'] as int,
        articleId: json['article_id'] as int,
        readingTime: json['reading_time'] as int,
        difficulty:
            Difficulty.fromJson(json['difficulty'] as Map<String, dynamic>),
        topics: Topics.fromJson(json['topics'] as Map<String, dynamic>),
        summary: Summary.fromJson(json['summary'] as Map<String, dynamic>),
        vocabulary: (json['vocabulary'] as List<dynamic>)
            .map((e) => Vocabulary.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
    } catch (e) {
      log.e('解析文章分析数据失败: $e');
      log.e('问题JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'article_id': articleId,
      'reading_time': readingTime,
      'difficulty': difficulty.toJson(),
      'topics': topics.toJson(),
      'summary': summary.toJson(),
      'vocabulary': vocabulary.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// 难度模型
class Difficulty {
  final String level;
  final String description;
  final List<String> features;

  Difficulty({
    required this.level,
    required this.description,
    required this.features,
  });

  factory Difficulty.fromJson(Map<String, dynamic> json) {
    return Difficulty(
      level: json['level'] as String,
      description: json['description'] as String,
      features:
          (json['features'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'description': description,
      'features': features,
    };
  }
}

// 主题模型
class Topics {
  final String primary;
  final List<String> secondary;
  final List<String> keywords;

  Topics({
    required this.primary,
    required this.secondary,
    required this.keywords,
  });

  factory Topics.fromJson(Map<String, dynamic> json) {
    return Topics(
      primary: json['primary'] as String,
      secondary:
          (json['secondary'] as List<dynamic>).map((e) => e as String).toList(),
      keywords:
          (json['keywords'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary': primary,
      'secondary': secondary,
      'keywords': keywords,
    };
  }
}

// 摘要模型
class Summary {
  final String short;
  final List<String> keyPoints;

  Summary({
    required this.short,
    required this.keyPoints,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      short: json['short'] as String,
      keyPoints: (json['key_points'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'short': short,
      'key_points': keyPoints,
    };
  }
}
