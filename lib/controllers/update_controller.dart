import 'package:get/get.dart';
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

  // 更新信息
  final Rx<VersionInfo?> _updateInfo = Rx<VersionInfo?>(null);
  final RxString _currentVersion = ''.obs;

  // 下载进度
  final RxInt _downloadProgress = 0.obs;
  final RxString _downloadStatus = ''.obs;

  // Getter
  bool get isCheckingUpdate => _isCheckingUpdate.value;
  bool get isDownloading => _isDownloading.value;
  bool get hasUpdate => _hasUpdate.value;
  bool get canInstall => _canInstall.value;
  VersionInfo? get updateInfo => _updateInfo.value;
  String get currentVersion => _currentVersion.value;
  int get downloadProgress => _downloadProgress.value;
  String get downloadStatus => _downloadStatus.value;

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
        log.i('APK下载完成: ${apkFile.path}');

        // 下载完成后，尝试安装
        await _installAPK(apkFile);
      } else {
        _downloadStatus.value = '下载失败';
        Get.snackbar(
          '下载失败',
          'APK文件下载失败',
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
            Get.snackbar(
              '安装提示',
              'APK文件已下载完成，请手动安装',
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 5),
            );
            return;
          }

          _canInstall.value = true;
        }

        // 调用系统安装器
        log.i('调用系统安装器...');
        await _updateService.installAPK(apkFile);

        Get.snackbar(
          '安装提示',
          'APK文件已准备就绪，请按照系统提示完成安装',
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

  /// 重置状态
  void resetState() {
    _isCheckingUpdate.value = false;
    _isDownloading.value = false;
    _hasUpdate.value = false;
    _downloadProgress.value = 0;
    _downloadStatus.value = '';
  }
}
