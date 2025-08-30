import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../utils/logger.dart';

/// 版本信息模型
class VersionInfo {
  final String version;
  final String name;
  final String changelog;
  final String downloadUrl;
  final String publishedAt;

  VersionInfo({
    required this.version,
    required this.name,
    required this.changelog,
    required this.downloadUrl,
    required this.publishedAt,
  });

  /// 从GitHub Release API响应创建版本信息
  factory VersionInfo.fromGitHubRelease(Map<String, dynamic> json) {
    final assets = json['assets'] as List<dynamic>? ?? [];
    String downloadUrl = '';

    // 查找APK文件的下载链接
    for (final asset in assets) {
      final assetMap = asset as Map<String, dynamic>;
      final name = assetMap['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        downloadUrl = assetMap['browser_download_url'] as String? ?? '';
        break;
      }
    }

    return VersionInfo(
      version: _cleanVersionTag(json['tag_name'] as String? ?? ''),
      name: json['name'] as String? ?? '',
      changelog: json['body'] as String? ?? '',
      downloadUrl: downloadUrl,
      publishedAt: json['published_at'] as String? ?? '',
    );
  }

  /// 清理版本标签，移除'v'前缀等
  static String _cleanVersionTag(String tagName) {
    // 移除'v'前缀
    if (tagName.startsWith('v')) {
      return tagName.substring(1);
    }
    return tagName;
  }
}

/// 应用更新服务
class UpdateService {
  // 🌟 使用GitHub Release API替代自建version.json
  static const String _githubApiUrl =
      'https://api.github.com/repos/Dolores18/mika_app/releases/latest';

  /// 检查是否有新版本
  Future<VersionInfo?> checkForUpdate(String currentVersion) async {
    try {
      log.i('开始检查应用更新...');
      log.i('当前版本: $currentVersion');

      final response = await http.get(Uri.parse(_githubApiUrl));
      if (response.statusCode == 200) {
        final versionInfo = VersionInfo.fromGitHubRelease(
          json.decode(response.body),
        );

        log.i('获取到远程版本信息: ${versionInfo.version}');

        // 🔍 处理"latest"标签或从name提取版本号
        String actualVersion = versionInfo.version;

        // 如果是"latest"标签或者需要从name中提取版本号
        if (versionInfo.version == 'latest' ||
            !_isValidSemanticVersion(versionInfo.version)) {
          // 从name字段中提取版本号 "Latest Build v1.0.0+20250830.1425"
          final nameMatch =
              RegExp(r'v?(\d+\.\d+\.\d+\+[\d.]+)').firstMatch(versionInfo.name);
          if (nameMatch != null) {
            actualVersion = nameMatch.group(1)!;
            log.i('从name提取到版本号: $actualVersion');
          } else {
            log.w('无法从name中提取有效版本号: ${versionInfo.name}');
            return null;
          }
        }

        // 创建标准化的VersionInfo对象
        final standardizedVersionInfo = VersionInfo(
          version: actualVersion,
          name: versionInfo.name,
          changelog: versionInfo.changelog,
          downloadUrl: versionInfo.downloadUrl,
          publishedAt: versionInfo.publishedAt,
        );

        // 比较版本号 - 只要版本不同就提示更新
        if (standardizedVersionInfo.version != currentVersion) {
          log.i(
              '发现新版本: ${standardizedVersionInfo.version} (当前: $currentVersion)');
          return standardizedVersionInfo;
        } else {
          log.i('当前已是最新版本');
          return null;
        }
      } else {
        log.w('检查更新失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log.e('检查更新异常: $e');
      return null;
    }
  }

  /// 下载APK文件
  Future<File?> downloadAPK(Function(int, int) onProgress) async {
    try {
      log.i('开始下载APK文件...');

      // 检查存储权限
      final storagePermission = await _checkStoragePermission();
      if (!storagePermission) {
        log.e('存储权限被拒绝');
        return null;
      }

      // 🌟 获取GitHub Release信息来获取APK下载链接
      final releaseResponse = await http.get(Uri.parse(_githubApiUrl));
      if (releaseResponse.statusCode != 200) {
        log.e('无法获取Release信息: HTTP ${releaseResponse.statusCode}');
        return null;
      }

      final versionInfo = VersionInfo.fromGitHubRelease(
        json.decode(releaseResponse.body),
      );

      if (versionInfo.downloadUrl.isEmpty) {
        log.e('未找到APK下载链接');
        return null;
      }

      log.i('获取到APK下载URL: ${versionInfo.downloadUrl}');

      // 🌟 下载到应用外部目录，系统安装器可以访问
      final appExternalDir = await getExternalStorageDirectory();
      if (appExternalDir == null) {
        log.e('无法获取外部存储目录');
        return null;
      }

      // 直接使用应用外部目录，不需要额外权限
      final apkFile = File('${appExternalDir.path}/mika-app-latest.apk');

      // 如果文件已存在，先删除
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final request = http.Request('GET', Uri.parse(versionInfo.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 0;
        int downloadedBytes = 0;

        final sink = apkFile.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          if (totalBytes > 0) {
            onProgress(downloadedBytes, totalBytes);
          }
        }

        await sink.close();

        log.i('APK下载完成: ${apkFile.path}');
        return apkFile;
      } else {
        log.e('下载APK失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log.e('下载APK异常: $e');
      return null;
    }
  }

  /// 检查存储权限
  Future<bool> _checkStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        // 使用应用外部目录 (getExternalStorageDirectory) 不需要存储权限
        // 这个目录在 Android/data/包名/files/ 下，应用可以直接访问
        log.i('使用应用外部目录，无需存储权限');
        return true;
      }
      return true;
    } catch (e) {
      log.e('检查存储权限失败: $e');
      return false;
    }
  }

  /// 获取Android版本
  Future<int> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.version.sdkInt;
      }
      return 30;
    } catch (e) {
      log.e('获取Android版本失败: $e');
      return 30; // 默认Android 11
    }
  }

  /// 检查是否有安装APK的权限
  Future<bool> canInstallAPK() async {
    if (Platform.isAndroid) {
      try {
        // 不做预判，让系统在实际安装时处理权限
        log.i('权限将由系统在安装时自动处理');
        return true; // 返回true，让安装流程继续
      } catch (e) {
        log.e('检查安装权限失败: $e');
        return false;
      }
    }
    return false;
  }

  /// 请求安装权限 - 由系统在安装时自动处理
  Future<bool> requestInstallPermission() async {
    if (Platform.isAndroid) {
      try {
        // 不做预判，让系统在安装APK时自动弹出权限请求
        log.i('系统将在安装时自动请求权限');
        return true; // 返回true，让安装流程继续
      } catch (e) {
        log.e('请求安装权限失败: $e');
        return false;
      }
    }
    return false;
  }

  /// 打开应用设置页面
  Future<void> openAppSettings() async {
    try {
      if (Platform.isAndroid) {
        log.i('打开Android应用设置页面');

        // 跳转到应用的"安装未知应用"设置页面
        final intent = AndroidIntent(
          action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
          data: 'package:com.example.mika_app',
          flags: <int>[0x10000000], // FLAG_ACTIVITY_NEW_TASK
        );

        await intent.launch();
        log.i('已打开应用设置页面');
      } else {
        log.w('非Android平台，无法打开应用设置');
      }
    } catch (e) {
      log.e('打开应用设置失败: $e');
      // 如果无法打开具体设置页面，尝试打开应用信息页面
      try {
        log.i('尝试打开应用信息页面');
        final intent = AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:com.example.mika_app',
          flags: <int>[0x10000000], // FLAG_ACTIVITY_NEW_TASK
        );
        await intent.launch();
      } catch (e2) {
        log.e('打开应用信息页面也失败: $e2');
      }
    }
  }

  /// 安装APK文件 - 直接调用系统安装器
  Future<void> installAPK(File apkFile) async {
    try {
      if (Platform.isAndroid) {
        log.i('直接调用系统安装器: ${apkFile.path}');

        // 直接调用系统安装Intent，让系统处理权限
        await _openAPKFile(apkFile);

        log.i('安装Intent已发送，系统将处理权限和安装流程');
      }
    } catch (e) {
      log.e('调用系统安装器失败: $e');
      rethrow;
    }
  }

  /// 打开APK文件进行安装 - 使用正确的FileProvider
  Future<void> _openAPKFile(File apkFile) async {
    try {
      log.i('启动系统安装器: ${apkFile.path}');

      // 基本文件检查
      if (!await apkFile.exists()) {
        throw Exception('APK文件不存在');
      }

      if (!Platform.isAndroid) {
        throw Exception('当前平台不支持APK安装');
      }

      // 获取Android版本
      final androidVersion = await _getAndroidVersion();
      log.i('Android版本: $androidVersion');

      // 添加文件信息调试
      final fileSize = await apkFile.length();
      log.i('APK文件大小: $fileSize bytes');

      String dataUri;
      if (androidVersion >= 24) {
        // Android 7.0+ 必须使用FileProvider
        final fileName = apkFile.path.split('/').last;
        dataUri =
            'content://com.example.mika_app.fileprovider/external_app_files/$fileName';
        log.i('使用FileProvider URI: $dataUri');
        log.i('文件名: $fileName');
        log.i('完整路径: ${apkFile.path}');
      } else {
        // Android 6.0及以下可以使用file://
        dataUri = 'file://${apkFile.path}';
        log.i('使用file URI: $dataUri');
      }

      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: dataUri,
        type: 'application/vnd.android.package-archive',
        flags: <int>[
          0x10000000, // FLAG_ACTIVITY_NEW_TASK
          0x00000001, // FLAG_GRANT_READ_URI_PERMISSION
        ],
      );

      log.i('准备启动Intent...');
      // 启动安装Intent
      await intent.launch();
      log.i('Intent启动成功！系统应该显示安装界面');
    } catch (e) {
      log.e('启动系统安装器失败: $e');
      log.i('APK文件位置: ${apkFile.path}');
      rethrow;
    }
  }

  /// 检查是否为有效的语义化版本号
  bool _isValidSemanticVersion(String version) {
    try {
      Version.parse(version);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 比较版本号 - 使用语义化版本比较
  int _compareVersions(String version1, String version2) {
    try {
      // 🌟 使用pub_semver进行更准确的版本比较
      final v1 = Version.parse(version1);
      final v2 = Version.parse(version2);

      if (v1 > v2) return 1;
      if (v1 < v2) return -1;
      return 0;
    } catch (e) {
      log.w('版本号解析失败，使用简单字符串比较: $e');
      log.w('版本1: $version1, 版本2: $version2');

      // 降级到简单的字符串比较
      return version1.compareTo(version2);
    }
  }
}
