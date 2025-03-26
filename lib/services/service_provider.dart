// lib/services/service_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './api_service.dart';
import './dictionary_service.dart';
import './ai_service.dart';

// API服务提供者
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

// 字典服务提供者
final dictionaryServiceProvider = Provider<DictionaryService>((ref) {
  return DictionaryService();
});

// AI服务提供者
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});
