import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../utils/logger.dart';

class HistoryService {
  static const _historyKey = 'reading_history';
  static const _maxHistoryCount = 10;

  // Add an article to the history with duration
  Future<void> addArticleToHistory(
      Article article, int durationInSeconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> historyJson = prefs.getStringList(_historyKey) ?? [];

      // Decode to a list of maps
      List<Map<String, dynamic>> history = historyJson
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .toList();

      // Remove if already exists to move it to the top
      history.removeWhere((item) => item['id'] == article.id.toString());

      // Create a summary map
      final articleSummary = {
        'id': article.id.toString(),
        'title': article.title,
        'issueDate': article.issueDate ?? '',
        'sectionTitle': article.sectionTitle,
        'duration': durationInSeconds, // Store duration in seconds
      };

      // Add to the beginning of the list
      history.insert(0, articleSummary);

      // Limit to max count
      if (history.length > _maxHistoryCount) {
        history = history.sublist(0, _maxHistoryCount);
      }

      // Encode back to a list of strings
      final List<String> updatedHistoryJson =
          history.map((item) => json.encode(item)).toList();

      await prefs.setStringList(_historyKey, updatedHistoryJson);
      log.i(
          'Article ${article.id} added to history. Duration: $durationInSeconds seconds.');
    } catch (e) {
      log.e('Failed to add article to history: $e');
    }
  }

  // Get the reading history
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> historyJson = prefs.getStringList(_historyKey) ?? [];

      final List<Map<String, dynamic>> history = historyJson
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .toList();

      log.i('Retrieved ${history.length} items from history.');
      return history;
    } catch (e) {
      log.e('Failed to get history: $e');
      return [];
    }
  }

  // Clear the history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      log.i('Reading history cleared.');
    } catch (e) {
      log.e('Failed to clear history: $e');
    }
  }
}
