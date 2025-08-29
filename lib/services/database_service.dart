import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/highlight_models.dart';
import '../utils/logger.dart';

/// 数据库服务 - 管理Isar数据库实例
class DatabaseService {
  static DatabaseService? _instance;
  static Isar? _isar;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  /// 获取Isar实例
  Future<Isar> get database async {
    if (_isar != null) return _isar!;

    try {
      final dir = await getApplicationDocumentsDirectory();

      _isar = await Isar.open(
        [
          VocabularyHighlightSchema,
        ],
        directory: dir.path,
        name: 'mika_app_db',
      );

      log.i('Isar数据库初始化成功');
      return _isar!;
    } catch (e) {
      log.e('Isar数据库初始化失败: $e');
      rethrow;
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_isar != null) {
      await _isar!.close();
      _isar = null;
      log.i('数据库已关闭');
    }
  }

  /// 清空所有数据（开发/测试用）
  Future<void> clearAllData() async {
    final isar = await database;
    await isar.writeTxn(() async {
      await isar.clear();
    });
    log.i('所有数据已清空');
  }
}
