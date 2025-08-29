import 'package:isar/isar.dart';

part 'highlight_models.g.dart';

/// 文本位置信息
@embedded
class TextPosition {
  late String paragraphId; // 段落ID（保留兼容性，但新版本使用文本偏移）
  late int startOffset; // 绝对文本开始位置（相对于document.body）
  late int endOffset; // 绝对文本结束位置（相对于document.body）
  late String context; // 完整上下文（prefix + 选中文本 + suffix）

  // 新增字段：用于文本偏移方式的额外验证
  String? prefix; // 选中文本前的上下文（用于验证）
  String? suffix; // 选中文本后的上下文（用于验证）

  TextPosition();

  TextPosition.create({
    required this.paragraphId,
    required this.startOffset,
    required this.endOffset,
    required this.context,
    this.prefix,
    this.suffix,
  });
}

/// 高亮颜色枚举
enum HighlightColor {
  yellow, // 黄色
  green, // 绿色
  blue, // 蓝色
  pink, // 粉色
  orange, // 橙色
}

/// 高亮颜色扩展
extension HighlightColorExtension on HighlightColor {
  String get colorValue {
    switch (this) {
      case HighlightColor.yellow:
        return '#FFFF00';
      case HighlightColor.green:
        return '#00FF00';
      case HighlightColor.blue:
        return '#0080FF';
      case HighlightColor.pink:
        return '#FF69B4';
      case HighlightColor.orange:
        return '#FFA500';
    }
  }

  String get displayName {
    switch (this) {
      case HighlightColor.yellow:
        return '黄色';
      case HighlightColor.green:
        return '绿色';
      case HighlightColor.blue:
        return '蓝色';
      case HighlightColor.pink:
        return '粉色';
      case HighlightColor.orange:
        return '橙色';
    }
  }
}

/// 词汇高亮注释模型
@collection
class VocabularyHighlight {
  Id id = Isar.autoIncrement;

  // 内容关联信息
  late String contentType; // 'english_article', 'japanese_news' 等
  late String contentId; // 文章ID

  // 高亮词汇信息
  late String word; // 高亮的单词
  String? originalForm; // 原始形式（如果是变位）
  late String selectedText; // 实际选中的文本

  // 位置信息
  late TextPosition position;

  // 学习相关信息
  String? translation; // 翻译（预留API接口）
  String? quickNote; // 快速备注
  String? pronunciation; // 发音（预留）

  // 高亮样式
  @enumerated
  late HighlightColor highlightColor;

  // 学习进度
  int reviewCount = 0; // 复习次数
  DateTime? lastReviewedAt; // 最后复习时间

  // 元数据
  late DateTime createdAt;
  late DateTime updatedAt;

  VocabularyHighlight();

  VocabularyHighlight.create({
    required this.contentType,
    required this.contentId,
    required this.word,
    required this.selectedText,
    required this.position,
    this.originalForm,
    this.translation,
    this.quickNote,
    this.pronunciation,
    this.highlightColor = HighlightColor.yellow,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  // 更新翻译
  void updateTranslation(String newTranslation) {
    translation = newTranslation;
    updatedAt = DateTime.now();
  }

  // 添加复习记录
  void markAsReviewed() {
    reviewCount++;
    lastReviewedAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  // 更新颜色
  void updateColor(HighlightColor newColor) {
    highlightColor = newColor;
    updatedAt = DateTime.now();
  }
}

/// 索引定义
@Name("contentTypeIndex")
@Index(type: IndexType.value)
const contentTypeIndex = [
  'contentType',
];

@Name("contentIdIndex")
@Index(type: IndexType.value)
const contentIdIndex = [
  'contentId',
];

@Name("wordIndex")
@Index(type: IndexType.value)
const wordIndex = [
  'word',
];

@Name("reviewIndex")
@Index(type: IndexType.value)
const reviewIndex = [
  'lastReviewedAt',
];
