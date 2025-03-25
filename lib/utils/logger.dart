import 'package:logger/logger.dart';

/// 日志工具类，提供统一的日志记录方法
///
/// 支持不同级别的日志：verbose, debug, info, warning, error, wtf
/// 在生产环境中可以轻松切换日志级别或完全禁用
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  late Logger _logger;

  // 单例模式
  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0, // 显示的调用栈方法数
        errorMethodCount: 8, // 错误日志显示的调用栈方法数
        lineLength: 120, // 单行长度
        colors: true, // 彩色输出
        printEmojis: true, // 打印表情符号
        printTime: true, // 打印时间
      ),
      // 设置最低日志级别，可以根据环境调整
      level: Level.verbose,
    );
  }

  /// 详细日志，用于输出详细的调试信息
  void v(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.v(message, error: error, stackTrace: stackTrace);
  }

  /// 调试日志，用于输出调试信息
  void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// 信息日志，用于输出一般信息
  void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// 警告日志，用于输出警告信息
  void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// 错误日志，用于输出错误信息
  void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// 严重错误日志，用于输出严重错误信息
  void wtf(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}

// 全局日志实例，方便在任何地方直接调用
final log = AppLogger();
