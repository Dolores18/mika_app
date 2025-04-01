// lib/widgets/dictionary/dictionary_card.dart
import 'package:flutter/material.dart';
import '../../models/article.dart';
import '../../models/vocabulary.dart';

class DictionaryCard extends StatelessWidget {
  final String word;
  final String translation;
  final String wordContext;
  final String example;
  final VoidCallback? onClose;
  final VoidCallback? onAddToVocabulary;
  final VoidCallback? onLookupMore;
  final bool isCompact; // 是否使用紧凑模式（在文章中弹出时）

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 8 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      word,
                      style: TextStyle(
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 发音按钮
                    IconButton(
                      icon: const Icon(Icons.volume_up, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        // 此处可以添加实际发音逻辑
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('发音功能即将上线')),
                        );
                      },
                    ),
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
          const Divider(),

          // 翻译
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              translation,
              style: TextStyle(
                fontSize: isCompact ? 16 : 18,
                color: Colors.blue[800],
                height: 1.3,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 上下文
          if (wordContext.isNotEmpty) ...[
            Text(
              "上下文:",
              style: TextStyle(
                fontSize: isCompact ? 13 : 14,
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
                style: TextStyle(
                  fontSize: isCompact ? 13 : 14,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // 例句
          if (example.isNotEmpty) ...[
            Text(
              "例句:",
              style: TextStyle(
                fontSize: isCompact ? 13 : 14,
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
                style: TextStyle(fontSize: isCompact ? 13 : 14, height: 1.3),
              ),
            ),
          ],

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
