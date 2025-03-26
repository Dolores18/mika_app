class DictionaryResult {
  final String word;
  final String? phonetic;
  final String? translation;
  final String? definition;
  final String? collins;
  final String? oxford;
  final String? tag;
  final String? exchange;

  DictionaryResult({
    required this.word,
    this.phonetic,
    this.translation,
    this.definition,
    this.collins,
    this.oxford,
    this.tag,
    this.exchange,
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
    );
  }

  // 用于调试的 toString 方法
  @override
  String toString() {
    return 'DictionaryResult{word: $word, phonetic: $phonetic, translation: $translation}';
  }
}
