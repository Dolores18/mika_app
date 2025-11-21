class DictionaryResult {
  final String word;
  final String? phonetic;
  final String? translation;
  final String? definition;
  final String? collins;
  final String? oxford;
  final String? tag;
  final String? exchange;
  final List<WordFrequency>? frequencies; // 词频信息

  DictionaryResult({
    required this.word,
    this.phonetic,
    this.translation,
    this.definition,
    this.collins,
    this.oxford,
    this.tag,
    this.exchange,
    this.frequencies,
  });

  factory DictionaryResult.fromJson(Map<String, dynamic> json) {
    return DictionaryResult(
      word: json['word'] ?? '',
      phonetic: json['phonetic']?.toString(),
      translation: json['translation']?.toString(),
      definition: json['definition']?.toString(),
      collins: json['collins']?.toString(),
      oxford: json['oxford']?.toString(),
      tag: json['tag']?.toString(),
      exchange: json['exchange']?.toString(),
      frequencies: null, // 词频需要单独获取
    );
  }

  // 用于调试的 toString 方法
  @override
  String toString() {
    return 'DictionaryResult{word: $word, phonetic: $phonetic, translation: $translation}';
  }
}

// 词频信息模型
class WordFrequency {
  final int frequency;
  final String pos; // 词性
  final int rank; // 排名
  final String word;

  WordFrequency({
    required this.frequency,
    required this.pos,
    required this.rank,
    required this.word,
  });

  factory WordFrequency.fromJson(Map<String, dynamic> json) {
    return WordFrequency(
      frequency: json['frequency'] ?? 0,
      pos: json['pos'] ?? '',
      rank: json['rank'] ?? 0,
      word: json['word'] ?? '',
    );
  }
}
