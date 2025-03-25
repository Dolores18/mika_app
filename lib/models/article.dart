// 文章难度枚举
enum ArticleDifficulty {
  easy, // 初级
  medium, // 中级
  hard, // 高级
}

class Article {
  final int id; // 文章ID
  final String title; // 标题
  final int sectionId; // 章节ID
  final String sectionTitle; // 章节标题
  final int issueId; // 期号ID
  final String issueDate; // 发布日期
  final String issueTitle; // 期号标题
  final int order; // 排序
  final String path; // 文件路径
  final bool hasImages; // 是否有图片
  final String? audioUrl; // 音频URL
  ArticleAnalysis? analysis;

  Article({
    required this.id,
    required this.title,
    required this.sectionId,
    required this.sectionTitle,
    required this.issueId,
    required this.issueDate,
    required this.issueTitle,
    required this.order,
    required this.path,
    required this.hasImages,
    this.audioUrl,
    this.analysis,
  });

  // 从JSON创建Article对象
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'],
      title: json['title'],
      sectionId: json['section_id'],
      sectionTitle: json['section_title'],
      issueId: json['issue_id'],
      issueDate: json['issue_date'],
      issueTitle: json['issue_title'],
      order: json['order'],
      path: json['path'],
      hasImages: json['has_images'],
      audioUrl: json['audio_url'],
      analysis:
          json['analysis'] != null
              ? ArticleAnalysis.fromJson(json['analysis'])
              : null,
    );
  }

  // 将Article对象转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'section_id': sectionId,
      'section_title': sectionTitle,
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
    return ArticleAnalysis(
      id: json['id'],
      articleId: json['article_id'],
      readingTime: json['reading_time'],
      difficulty: Difficulty.fromJson(json['difficulty']),
      topics: Topics.fromJson(json['topics']),
      summary: Summary.fromJson(json['summary']),
      vocabulary:
          (json['vocabulary'] as List<dynamic>)
              .map((v) => Vocabulary.fromJson(v))
              .toList(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'article_id': articleId,
      'reading_time': readingTime,
      'difficulty': difficulty.toJson(),
      'topics': topics.toJson(),
      'summary': summary.toJson(),
      'vocabulary': vocabulary.map((v) => v.toJson()).toList(),
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
      level: json['level'],
      description: json['description'],
      features: List<String>.from(json['features']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'level': level, 'description': description, 'features': features};
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
    // 确保能正确处理UTF-8字符
    try {
      // 检查primary是否为字符串
      String primaryTopic = '';
      if (json['primary'] is String) {
        primaryTopic = json['primary'];
      } else {
        print('警告: 主题不是字符串: ${json['primary']}');
        primaryTopic = '未知主题';
      }

      // 处理secondary数组
      List<String> secondaryTopics = [];
      if (json['secondary'] is List) {
        secondaryTopics = List<String>.from(
          (json['secondary'] as List).map((item) {
            if (item is String) {
              return item;
            } else {
              print('警告: 次要主题项不是字符串: $item');
              return '未知';
            }
          }),
        );
      } else {
        print('警告: 次要主题不是列表: ${json['secondary']}');
      }

      // 处理keywords数组
      List<String> topicKeywords = [];
      if (json['keywords'] is List) {
        topicKeywords = List<String>.from(
          (json['keywords'] as List).map((item) {
            if (item is String) {
              return item;
            } else {
              print('警告: 关键词项不是字符串: $item');
              return '未知';
            }
          }),
        );
      } else {
        print('警告: 关键词不是列表: ${json['keywords']}');
      }

      return Topics(
        primary: primaryTopic,
        secondary: secondaryTopics,
        keywords: topicKeywords,
      );
    } catch (e) {
      print('解析Topics时出错: $e');
      // 返回一个默认的Topics对象
      return Topics(primary: '未知主题', secondary: [], keywords: []);
    }
  }

  Map<String, dynamic> toJson() {
    return {'primary': primary, 'secondary': secondary, 'keywords': keywords};
  }
}

// 摘要模型
class Summary {
  final String short;
  final List<String> keyPoints;

  Summary({required this.short, required this.keyPoints});

  factory Summary.fromJson(Map<String, dynamic> json) {
    try {
      // 检查short是否为字符串
      String shortSummary = '';
      if (json['short'] is String) {
        shortSummary = json['short'];
      } else {
        print('警告: 摘要不是字符串: ${json['short']}');
        shortSummary = '无摘要';
      }

      // 处理keyPoints数组
      List<String> points = [];
      if (json['key_points'] is List) {
        points = List<String>.from(
          (json['key_points'] as List).map((item) {
            if (item is String) {
              return item;
            } else {
              print('警告: 关键点不是字符串: $item');
              return '未知要点';
            }
          }),
        );
      } else {
        print('警告: 关键点不是列表: ${json['key_points']}');
      }

      return Summary(short: shortSummary, keyPoints: points);
    } catch (e) {
      print('解析Summary时出错: $e');
      // 返回一个默认的Summary对象
      return Summary(short: '无摘要', keyPoints: []);
    }
  }

  Map<String, dynamic> toJson() {
    return {'short': short, 'key_points': keyPoints};
  }
}

// 词汇模型
class Vocabulary {
  final String word;
  final String translation;
  final String context;
  final String example;

  Vocabulary({
    required this.word,
    required this.translation,
    required this.context,
    required this.example,
  });

  factory Vocabulary.fromJson(Map<String, dynamic> json) {
    return Vocabulary(
      word: json['word'],
      translation: json['translation'],
      context: json['context'],
      example: json['example'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'translation': translation,
      'context': context,
      'example': example,
    };
  }
}
