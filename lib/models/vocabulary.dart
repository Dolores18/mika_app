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
      word: json['word'] as String,
      translation: json['translation'] as String,
      context: json['context'] as String,
      example: json['example'] as String,
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
