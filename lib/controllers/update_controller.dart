import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/update_service.dart';
import '../utils/logger.dart';

/// 应用更新控制器
class UpdateController extends GetxController {
  final UpdateService _updateService = UpdateService();

  // 更新状态
  final RxBool _isCheckingUpdate = false.obs;
  final RxBool _isDownloading = false.obs;
  final RxBool _hasUpdate = false.obs;
  final RxBool _canInstall = false.obs;
  final RxBool _downloadCompleted = false.obs;

  // 更新信息
  final Rx<VersionInfo?> _updateInfo = Rx<VersionInfo?>(null);
  final RxString _currentVersion = ''.obs;

  // 下载进度
  final RxInt _downloadProgress = 0.obs;
  final RxString _downloadStatus = ''.obs;
  final Rx<File?> _downloadedFile = Rx<File?>(null);

  // Getter
  bool get isCheckingUpdate => _isCheckingUpdate.value;
  bool get isDownloading => _isDownloading.value;
  bool get hasUpdate => _hasUpdate.value;
  bool get canInstall => _canInstall.value;
  bool get downloadCompleted => _downloadCompleted.value;
  VersionInfo? get updateInfo => _updateInfo.value;
  String get currentVersion => _currentVersion.value;
  int get downloadProgress => _downloadProgress.value;
  String get downloadStatus => _downloadStatus.value;
  File? get downloadedFile => _downloadedFile.value;

  @override
  void onInit() {
    super.onInit();
    _initVersion();
    _checkInstallPermission();
  }

  /// 初始化版本信息
  void _initVersion() {
    // 从pubspec.yaml获取当前版本，这里先硬编码，后续可以从配置读取
    _currentVersion.value = '1.0.0+1';
  }

  /// 检查安装权限
  Future<void> _checkInstallPermission() async {
    try {
      final canInstallAPK = await _updateService.canInstallAPK();
      _canInstall.value = canInstallAPK;
      log.i('安装权限检查完成: $canInstallAPK');
    } catch (e) {
      log.e('检查安装权限失败: $e');
      _canInstall.value = false;
    }
  }

  /// 检查更新
  Future<void> checkForUpdate() async {
    if (_isCheckingUpdate.value) return;

    try {
      _isCheckingUpdate.value = true;
      _hasUpdate.value = false;
      _updateInfo.value = null;

      log.i('开始检查应用更新...');

      final versionInfo =
          await _updateService.checkForUpdate(_currentVersion.value);

      if (versionInfo != null) {
        _updateInfo.value = versionInfo;
        _hasUpdate.value = true;

        log.i('发现新版本: ${versionInfo.version}');
        Get.snackbar(
          '发现新版本',
          '版本 ${versionInfo.version} 可用',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      } else {
        log.i('当前已是最新版本');
        Get.snackbar(
          '已是最新版本',
          '当前版本已是最新',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      log.e('检查更新失败: $e');
      Get.snackbar(
        '检查失败',
        '检查更新失败，请检查网络连接',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    } finally {
      _isCheckingUpdate.value = false;
    }
  }

  /// 下载APK
  Future<void> downloadAPK() async {
    if (_isDownloading.value || _updateInfo.value == null) return;

    try {
      _isDownloading.value = true;
      _downloadProgress.value = 0;
      _downloadStatus.value = '准备下载...';

      log.i('开始下载APK文件...');

      final apkFile = await _updateService.downloadAPK((downloaded, total) {
        if (total > 0) {
          final progress = ((downloaded / total) * 100).round();
          _downloadProgress.value = progress;
          _downloadStatus.value = '下载中... $progress%';
        }
      });

      if (apkFile != null) {
        _downloadStatus.value = '下载完成';
        _downloadCompleted.value = true;
        _downloadedFile.value = apkFile;
        log.i('APK下载完成: ${apkFile.path}');

        // 显示安装引导
        _showInstallGuide(apkFile);
      } else {
        _downloadStatus.value = '下载失败';
        Get.snackbar(
          '下载失败',
          'APK文件下载失败，请检查网络连接',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      log.e('下载APK失败: $e');
      _downloadStatus.value = '下载失败';
      Get.snackbar(
        '下载失败',
        '下载过程中出现错误',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    } finally {
      _isDownloading.value = false;
    }
  }

  /// 安装APK
  Future<void> _installAPK(File apkFile) async {
    try {
      if (Platform.isAndroid) {
        // 检查安装权限
        if (!_canInstall.value) {
          log.i('没有安装权限，请求权限...');
          final granted = await _updateService.requestInstallPermission();

          if (!granted) {
            log.w('用户拒绝安装权限');
            _showPermissionGuide(apkFile);
            return;
          }

          _canInstall.value = true;
        }

        // 调用系统安装器
        log.i('调用系统安装器...');
        await _updateService.installAPK(apkFile);

        Get.snackbar(
          '安装启动',
          '正在启动系统安装器，请按照提示完成安装',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      log.e('安装APK失败: $e');
      Get.snackbar(
        '安装失败',
        '安装过程中出现错误',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// 请求安装权限
  Future<void> requestInstallPermission() async {
    try {
      final granted = await _updateService.requestInstallPermission();
      _canInstall.value = granted;

      if (granted) {
        log.i('安装权限已获取');
        Get.snackbar(
          '权限已获取',
          '现在可以安装APK文件了',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
      } else {
        log.w('用户拒绝安装权限');
        Get.snackbar(
          '权限被拒绝',
          '请在设置中手动开启安装权限',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      log.e('请求安装权限失败: $e');
    }
  }

  /// 打开应用设置
  Future<void> openAppSettings() async {
    try {
      await _updateService.openAppSettings();
    } catch (e) {
      log.e('打开应用设置失败: $e');
    }
  }

  /// 显示权限引导对话框
  void _showPermissionGuide(File apkFile) {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.orange),
            SizedBox(width: 8),
            Text('需要开启安装权限'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('安装失败，可能需要手动开启安装权限'),
            SizedBox(height: 12),
            Text('📱 解决方法：', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. 点击"去设置"打开权限页面'),
            Text('2. 找到并开启"允许安装未知应用"'),
            Text('3. 返回应用重新尝试安装'),
            SizedBox(height: 12),
            Text('💡 提示：开启后可直接安装，无需重复设置',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('稍后设置'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// 显示安装引导
  void _showInstallGuide(File apkFile) {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download_done, color: Colors.green),
            SizedBox(width: 8),
            Text('下载完成'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('APK文件已下载完成！'),
            const SizedBox(height: 12),
            const Text('📱 安装步骤：',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('1. 点击"立即安装"按钮'),
            const Text('2. 系统会自动请求安装权限'),
            const Text('3. 允许权限后按提示完成安装'),
            const SizedBox(height: 12),
            Text('📁 文件位置：\n${apkFile.path}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('稍后安装'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              installDownloadedAPK();
            },
            child: const Text('立即安装'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// 安装已下载的APK
  Future<void> installDownloadedAPK() async {
    final apkFile = _downloadedFile.value;
    if (apkFile != null) {
      await _installAPK(apkFile);
    }
  }

  /// 打开GitHub Release页面
  Future<void> openGitHubRelease() async {
    const url = 'https://github.com/Dolores18/mika_app/releases';
    await _openUrl(url, '打开GitHub Release页面');
  }

  /// 打开GitHub项目主页
  Future<void> openGitHubRepo() async {
    const url = 'https://github.com/Dolores18/mika_app';
    await _openUrl(url, '打开GitHub项目页面');
  }

  /// 发送反馈邮件
  Future<void> sendFeedbackEmail() async {
    const url =
        'mailto:aimer8073@gmail.com?subject=Mika App 反馈&body=请在此输入您的反馈内容...';
    await _openUrl(url, '打开邮件客户端');
  }

  /// 通用URL打开方法
  Future<void> _openUrl(String url, String description) async {
    try {
      log.i('尝试$description: $url');

      final uri = Uri.parse(url);
      final canLaunch = await canLaunchUrl(uri);

      if (canLaunch) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 使用外部应用打开
        );
        log.i('$description成功');
      } else {
        log.w('无法$description');
        Get.snackbar(
          '打开失败',
          '无法打开链接，请检查是否安装了相应的应用',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      log.e('$description失败: $e');
      Get.snackbar(
        '操作失败',
        '打开链接时出现错误',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// 重置状态
  void resetState() {
    _isCheckingUpdate.value = false;
    _isDownloading.value = false;
    _hasUpdate.value = false;
    _downloadCompleted.value = false;
    _downloadProgress.value = 0;
    _downloadStatus.value = '';
    _downloadedFile.value = null;
  }
}
