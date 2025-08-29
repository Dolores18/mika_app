import 'dart:io';
import 'dart:convert'; // Added missing import for json.decode
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

/// 版本信息模型
class VersionInfo {
  final String version;
  final String buildTime;
  final String commit;
  final String branch;
  final String downloadUrl;

  VersionInfo({
    required this.version,
    required this.buildTime,
    required this.commit,
    required this.branch,
    required this.downloadUrl,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'] ?? '',
      buildTime: json['build_time'] ?? '',
      commit: json['commit'] ?? '',
      branch: json['branch'] ?? '',
      downloadUrl: json['download_url'] ?? '',
    );
  }
}

/// 应用更新服务
class UpdateService {
  static const String _versionUrl =
      'https://github.com/你的用户名/mika_app/raw/use_html/.github/releases/version.json';
  static const String _apkUrl =
      'https://github.com/你的用户名/mika_app/raw/use_html/.github/releases/mika-app-latest.apk';

  /// 检查是否有新版本
  Future<VersionInfo?> checkForUpdate(String currentVersion) async {
    try {
      log.i('开始检查应用更新...');

      final response = await http.get(Uri.parse(_versionUrl));
      if (response.statusCode == 200) {
        final versionInfo = VersionInfo.fromJson(
          json.decode(response.body),
        );

        log.i('获取到版本信息: ${versionInfo.version}');

        // 比较版本号
        if (_compareVersions(versionInfo.version, currentVersion) > 0) {
          log.i('发现新版本: ${versionInfo.version}');
          return versionInfo;
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

      final appDir = await getApplicationDocumentsDirectory();
      final apkFile = File('${appDir.path}/mika-app-latest.apk');

      // 如果文件已存在，先删除
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final request = http.Request('GET', Uri.parse(_apkUrl));
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

  /// 比较版本号
  int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();

    final maxLength =
        v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final v1 = i < v1Parts.length ? v1Parts[i] : 0;
      final v2 = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1 > v2) return 1;
      if (v1 < v2) return -1;
    }

    return 0;
  }
}
