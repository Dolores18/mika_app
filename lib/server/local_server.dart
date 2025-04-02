import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart' as shelf_static;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';
import 'package:http/http.dart' as http;
import '../services/article_service.dart';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;

class LocalServer {
  static HttpServer? _server;
  static const int _port = 8080;
  static const String _baseUrl = 'http://localhost:$_port';
  static Directory? _rendererDir;
  static bool _isStarting = false;
  static Completer<String>? _startCompleter;

  static Future<String> start() async {
    // 如果服务器已经在运行中，直接返回基础URL
    if (_server != null) {
      log.i('本地服务器已经在运行中');
      return _baseUrl;
    }

    // 如果服务器正在启动中，等待启动完成
    if (_isStarting && _startCompleter != null) {
      log.i('本地服务器正在启动中，等待...');
      return _startCompleter!.future;
    }

    // 标记服务器正在启动，并创建完成器
    _isStarting = true;
    _startCompleter = Completer<String>();

    try {
      log.i('开始启动本地服务器...');
      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      _rendererDir = Directory(path.join(appDir.path, 'renderer'));

      // 确保renderer目录存在
      if (!await _rendererDir!.exists()) {
        await _rendererDir!.create(recursive: true);
      }

      // 复制assets中的renderer文件到本地目录
      await _copyRendererAssets();

      // 创建静态文件处理器
      final staticHandler = shelf_static.createStaticHandler(
        _rendererDir!.path,
        defaultDocument: 'index.html',
        listDirectories: false,
      );

      // 创建API处理器
      final apiHandler = shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler(_handleApi);

      // 创建CORS中间件
      final corsMiddleware = shelf.createMiddleware(
        requestHandler: (shelf.Request request) {
          if (request.method == 'OPTIONS') {
            return shelf.Response.ok('', headers: _corsHeaders);
          }
          return null;
        },
        responseHandler: (shelf.Response response) {
          return response.change(headers: _corsHeaders);
        },
      );

      // 创建主处理器
      final handler = shelf.Pipeline().addMiddleware(corsMiddleware).addHandler(
        (request) {
          log.i(
              '收到请求: ${request.method} ${request.url.path}，完整URL: ${request.url}');

          // 打印所有请求头
          log.i('请求头: ${request.headers}');

          if (request.url.path.startsWith('/api/')) {
            log.i('转发到API处理器: ${request.url.path}');
            return apiHandler(request);
          }

          // 检查特定的文件请求
          if (request.url.path == 'renderer.js' ||
              request.url.path == 'styles.css' ||
              request.url.path == 'economist.css' ||
              request.url.path == 'index.html' ||
              request.url.path == '' ||
              request.url.path == '/' ||
              request.url.path == '/renderer.js' ||
              request.url.path == '/styles.css' ||
              request.url.path == '/economist.css' ||
              request.url.path == '/index.html') {
            String fileName;
            if (request.url.path == 'renderer.js' ||
                request.url.path == '/renderer.js') {
              fileName = 'renderer.js';
            } else if (request.url.path == 'styles.css' ||
                request.url.path == '/styles.css') {
              fileName = 'styles.css';
            } else if (request.url.path == 'economist.css' ||
                request.url.path == '/economist.css') {
              fileName = 'economist.css';
            } else {
              fileName = 'index.html'; // 默认为index.html
            }

            log.i('请求文件: $fileName，路径: ${request.url.path}');

            final file = File(path.join(_rendererDir!.path, fileName));
            if (file.existsSync()) {
              String contentType;
              if (fileName.endsWith('.js')) {
                contentType = 'application/javascript; charset=utf-8';
              } else if (fileName.endsWith('.css')) {
                contentType = 'text/css; charset=utf-8';
              } else {
                contentType = 'text/html; charset=utf-8';
              }

              log.i('提供文件: ${file.path}，内容类型: $contentType');
              return shelf.Response.ok(
                file.readAsBytesSync(),
                headers: {'Content-Type': contentType, ...(_corsHeaders)},
              );
            } else {
              log.e('文件不存在: $fileName');
            }
          }

          log.i('使用静态文件处理器处理请求: ${request.url}');
          return staticHandler(request);
        },
      );

      // 启动服务器
      _server = await shelf_io.serve(handler, 'localhost', _port);
      log.i('本地服务器启动成功: $_baseUrl');

      // 完成启动，通知等待者
      _startCompleter!.complete(_baseUrl);
      _isStarting = false;

      return _baseUrl;
    } catch (e) {
      log.e('启动本地服务器失败: $e');

      // 重置启动状态
      _isStarting = false;
      _startCompleter!.completeError(e);

      rethrow;
    }
  }

  // 复制assets中的renderer文件到本地目录
  static Future<void> _copyRendererAssets() async {
    if (_rendererDir == null) {
      log.e('_copyRendererAssets: rendererDir为空');
      return;
    }

    try {
      log.i('开始复制renderer资产文件...');

      // 复制index.html
      await _copyAssetFile('assets/renderer/index.html', 'index.html');

      // 复制renderer.js
      await _copyAssetFile('assets/renderer/renderer.js', 'renderer.js');

      // 复制styles.css
      await _copyAssetFile('assets/renderer/styles.css', 'styles.css');

      // 复制economist.css
      await _copyAssetFile('assets/renderer/economist.css', 'economist.css');

      log.i('renderer资产文件复制完成');
    } catch (e) {
      log.e('复制renderer资产文件失败: $e');
    }
  }

  // 复制单个资产文件到本地目录
  static Future<void> _copyAssetFile(String assetPath, String fileName) async {
    try {
      log.i('复制资产文件: $assetPath -> $fileName');
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      final file = File(path.join(_rendererDir!.path, fileName));
      await file.writeAsBytes(bytes);
      log.i('资产文件复制成功: ${file.path}');
    } catch (e) {
      log.e('复制资产文件失败: $assetPath, 错误: $e');
      rethrow;
    }
  }

  static Future<void> stop() async {
    if (_server != null) {
      log.i('正在关闭本地服务器...');

      try {
        await _server!.close(force: false);
        log.i('本地服务器已正常关闭');
      } catch (e) {
        log.e('关闭本地服务器出错: $e');
        // 尝试强制关闭
        try {
          await _server!.close(force: true);
          log.i('本地服务器已强制关闭');
        } catch (e) {
          log.e('强制关闭本地服务器失败: $e');
        }
      } finally {
        _server = null;
        _isStarting = false;
        _startCompleter = null;
      }
    } else {
      log.i('本地服务器未运行，无需关闭');
    }
  }

  static Future<shelf.Response> _handleApi(shelf.Request request) async {
    try {
      log.i('=== 处理API请求开始 ===');

      // 从服务获取远程API基础URL
      String remoteApiBaseUrl;

      try {
        remoteApiBaseUrl = ArticleService.getBaseUrl();
        log.i('成功获取远程API基础URL: $remoteApiBaseUrl');
      } catch (e) {
        log.e('获取远程API基础URL异常: $e');
        return shelf.Response.internalServerError(
          body: '{"error": "Failed to get API base URL: $e"}',
          headers: {'Content-Type': 'application/json', ...(_corsHeaders)},
        );
      }

      // 检查baseUrl是否为空或无效
      if (remoteApiBaseUrl.isEmpty) {
        log.e('远程API基础URL为空字符串!');
        return shelf.Response.internalServerError(
          body: '{"error": "Remote API base URL is empty"}',
          headers: {'Content-Type': 'application/json', ...(_corsHeaders)},
        );
      }

      // 记录请求详情
      log.i('收到API请求: ${request.method} ${request.url}');
      log.i('请求头: ${request.headers}');

      final path = request.url.path;
      log.i('处理API请求路径: $path');

      // 检查是否有文章ID
      String? detectedArticleId;
      if (path.contains('/articles/')) {
        final parts = path.split('/');
        log.i('路径部分: ${parts.join(", ")}');

        for (int i = 0; i < parts.length; i++) {
          if (parts[i] == 'articles' && i + 1 < parts.length) {
            detectedArticleId = parts[i + 1];
            log.i('检测到文章ID: $detectedArticleId');

            // 检查是否为空
            if (detectedArticleId == null || detectedArticleId.isEmpty) {
              log.e('文章ID为空或无效');
              return shelf.Response.badRequest(
                body: '{"error": "Invalid article ID"}',
                headers: {
                  'Content-Type': 'application/json',
                  ...(_corsHeaders)
                },
              );
            }

            break;
          }
        }
      }

      // 检查文章ID格式
      if (detectedArticleId != null) {
        // 尝试解析为整数
        try {
          final idInt = int.parse(detectedArticleId);
          log.i('文章ID解析为整数: $idInt');
        } catch (e) {
          log.w('文章ID不是有效整数: $detectedArticleId, 错误: $e');
          // 继续处理，因为ID可能不是整数格式
        }
      }

      if (path.startsWith('/api/')) {
        // 构建远程API URL
        final remotePath = path.substring(4); // 移除前导的'/api'
        if (remotePath.isEmpty) {
          log.e('远程路径为空');
          return shelf.Response.badRequest(
            body: '{"error": "Empty remote path"}',
            headers: {'Content-Type': 'application/json', ...(_corsHeaders)},
          );
        }

        final remoteUrl = '$remoteApiBaseUrl$remotePath';
        log.i('转发请求到远程API: $remoteUrl');
        log.i('请求方法: ${request.method}');
        log.i('请求头: ${request.headers}');

        try {
          // 使用http客户端请求远程API
          final http.Client client = http.Client();
          log.i('开始请求远程API...');
          final stopwatch = Stopwatch()..start();

          // 确保URL有效
          try {
            final uri = Uri.parse(remoteUrl);
            log.i('解析的URI: ${uri.toString()}');
          } catch (e) {
            log.e('无效的远程URL: $remoteUrl, 错误: $e');
            return shelf.Response.internalServerError(
              body: '{"error": "Invalid remote URL: $e"}',
              headers: {'Content-Type': 'application/json', ...(_corsHeaders)},
            );
          }

          // 转发请求到远程API
          final response = await client
              .get(Uri.parse(remoteUrl))
              .timeout(const Duration(seconds: 15));

          stopwatch.stop();
          log.i('远程API响应耗时: ${stopwatch.elapsedMilliseconds}ms');
          log.i('远程API响应状态码: ${response.statusCode}');
          log.i('远程API响应头: ${response.headers}');
          log.i('远程API响应体大小: ${response.body.length} 字节');

          // 添加响应内容预览
          if (response.statusCode == 200) {
            final preview = response.body.length > 100
                ? response.body.substring(0, 100)
                : response.body;
            log.i('远程API响应内容预览: $preview');
          }

          // 确保Content-Type头部存在
          String contentType = response.headers['content-type'] ??
              'application/json; charset=utf-8';

          // 转发远程API的响应
          return shelf.Response(
            response.statusCode,
            body: response.body,
            headers: {
              'Content-Type': contentType,
              ...(_corsHeaders),
            },
          );
        } catch (e) {
          log.e('请求远程API失败: $e');
          // 如果是HTML请求，返回一个友好的错误页面
          if (path.contains('/html')) {
            return shelf.Response.ok(
              '''<!DOCTYPE html>
              <html>
              <head><title>加载失败</title></head>
              <body>
                <div style="text-align: center; padding: 20px;">
                  <h1 style="color: #e53935;">加载失败</h1>
                  <p>无法从远程服务器获取文章内容</p>
                  <p>错误信息: $e</p>
                  <p>请求的文章ID: ${detectedArticleId ?? '未检测到ID'}</p>
                  <p>远程URL: ${remoteUrl}</p>
                  <button onclick="window.location.reload()">重试</button>
                </div>
              </body>
              </html>''',
              headers: {
                'Content-Type': 'text/html; charset=utf-8',
                ...(_corsHeaders)
              },
            );
          }
          return shelf.Response.internalServerError(
            body: '{"error": "远程API请求失败: $e"}',
            headers: {'Content-Type': 'application/json', ...(_corsHeaders)},
          );
        }
      }

      log.w('未匹配的API路径: $path');
      return shelf.Response.notFound(
        '{"error": "API endpoint not found"}',
        headers: {'Content-Type': 'application/json', ...(_corsHeaders)},
      );
    } catch (e) {
      log.e('处理API请求时发生异常: $e');
      return shelf.Response.internalServerError(
        body: '{"error": "Internal server error: $e"}',
        headers: {'Content-Type': 'application/json', ...(_corsHeaders)},
      );
    }
  }

  static final Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };
}
