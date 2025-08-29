import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pub_semver/pub_semver.dart';
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

        // 比较版本号
        if (_compareVersions(standardizedVersionInfo.version, currentVersion) >
            0) {
          log.i('发现新版本: ${standardizedVersionInfo.version}');
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

      final appDir = await getApplicationDocumentsDirectory();
      final apkFile = File('${appDir.path}/mika-app-latest.apk');

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

  /// 检查是否有安装APK的权限
  Future<bool> canInstallAPK() async {
    if (Platform.isAndroid) {
      try {
        // 简化权限检查，直接返回false，引导用户手动安装
        log.i('Android平台，需要用户手动安装APK');
        return false;
      } catch (e) {
        log.e('检查安装权限失败: $e');
        return false;
      }
    }
    return false;
  }

  /// 请求安装权限
  Future<bool> requestInstallPermission() async {
    if (Platform.isAndroid) {
      try {
        log.i('Android平台不支持自动安装，需要用户手动操作');
        return false;
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
      log.i('引导用户手动安装APK');
      // 这里可以添加引导用户手动安装的逻辑
    } catch (e) {
      log.e('打开应用设置失败: $e');
    }
  }

  /// 安装APK文件
  Future<void> installAPK(File apkFile) async {
    try {
      if (Platform.isAndroid) {
        log.i('APK文件已下载到: ${apkFile.path}');
        log.i('请使用系统文件管理器打开此文件进行安装');
        log.i('或者将文件传输到电脑上安装');
      }
    } catch (e) {
      log.e('安装APK失败: $e');
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
