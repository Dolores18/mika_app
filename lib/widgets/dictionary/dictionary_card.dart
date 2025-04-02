// lib/widgets/dictionary/dictionary_card.dart
import 'package:flutter/material.dart';
import '../../models/article.dart';
import '../../models/vocabulary.dart';
import '../../models/dictionary_result.dart';

class DictionaryCard extends StatelessWidget {
  final String word;
  final String translation;
  final String wordContext;
  final String example;
  final VoidCallback? onClose;
  final VoidCallback? onAddToVocabulary;
  final VoidCallback? onLookupMore;
  final bool isCompact; // 是否使用紧凑模式（在文章中弹出时）
  final String? phonetic;
  final String? definition;
  final String? tag;
  final String? exchange;
  final String? collins;
  final String? oxford;

  const DictionaryCard({
    Key? key,
    required this.word,
    required this.translation,
    required this.wordContext,
    required this.example,
    this.onClose,
    this.onAddToVocabulary,
    this.onLookupMore,
    this.isCompact = false,
    this.phonetic,
    this.definition,
    this.tag,
    this.exchange,
    this.collins,
    this.oxford,
  }) : super(key: key);

  // 从Vocabulary模型创建词典卡片的工厂构造函数
  factory DictionaryCard.fromVocabulary({
    required Vocabulary vocabulary,
    VoidCallback? onClose,
    VoidCallback? onAddToVocabulary,
    VoidCallback? onLookupMore,
    bool isCompact = false,
  }) {
    return DictionaryCard(
      word: vocabulary.word,
      translation: vocabulary.translation,
      wordContext: vocabulary.context,
      example: vocabulary.example,
      onClose: onClose,
      onAddToVocabulary: onAddToVocabulary,
      onLookupMore: onLookupMore,
      isCompact: isCompact,
    );
  }

  // 从DictionaryResult模型创建词典卡片的新工厂构造函数
  factory DictionaryCard.fromDictionaryResult({
    required DictionaryResult result,
    VoidCallback? onClose,
    VoidCallback? onAddToVocabulary,
    VoidCallback? onLookupMore,
    bool isCompact = false,
  }) {
    return DictionaryCard(
      word: result.word,
      translation: result.translation ?? '',
      wordContext: '',
      example: '',
      phonetic: result.phonetic,
      definition: result.definition,
      tag: result.tag,
      exchange: result.exchange,
      collins: result.collins,
      oxford: result.oxford,
      onClose: onClose,
      onAddToVocabulary: onAddToVocabulary,
      onLookupMore: onLookupMore,
      isCompact: isCompact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单词和音标
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      word,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (phonetic != null && phonetic!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        "[$phonetic]",
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),

          const Divider(height: 24),

          // 中文释义
          if (translation.isNotEmpty) ...[
            Text(
              "中文释义：$translation",
              style: const TextStyle(fontSize: 16, color: Colors.blue),
            ),
            const SizedBox(height: 8),
          ],

          // 英文释义
          if (definition != null && definition!.isNotEmpty) ...[
            Text(
              "英文释义：$definition",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
          ],

          // 上下文（如果有）
          if (wordContext.isNotEmpty) ...[
            Text(
              "上下文:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                wordContext,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 例句（如果有）
          if (example.isNotEmpty) ...[
            Text(
              "例句:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                example,
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 词汇分类
          if (tag != null && tag!.isNotEmpty) ...[
            Text(
              "词汇分类：$tag",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
          ],

          // 变形
          if (exchange != null && exchange!.isNotEmpty) ...[
            Text(
              "变形：$exchange",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
          ],

          // 柯林斯星级和牛津核心
          Row(
            children: [
              if (collins != null && collins!.isNotEmpty && collins != '0') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "柯林斯星级：$collins",
                    style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (oxford != null && oxford!.isNotEmpty && oxford != '0') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "牛津核心：$oxford",
                    style: TextStyle(fontSize: 12, color: Colors.red[800]),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // 底部按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onLookupMore != null)
                TextButton.icon(
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text("查看详情"),
                  onPressed: onLookupMore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              if (onAddToVocabulary != null)
                TextButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text("添加到生词本"),
                  onPressed: onAddToVocabulary,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              if (onClose != null)
                TextButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text("关闭"),
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
