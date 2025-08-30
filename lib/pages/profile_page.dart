import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/bookmark_controller.dart';
import '../controllers/update_controller.dart';
import 'bookmark_page.dart';
import '../utils/logger.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final BookmarkController bookmarkController = Get.put(BookmarkController());
  final UpdateController updateController = Get.put(UpdateController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              const Text(
                '我的',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),

              // 用户信息卡片
              _buildUserInfoCard(),
              const SizedBox(height: 20),

              // 功能列表
              _buildFunctionList(),
              const SizedBox(height: 20),

              // 设置列表
              _buildSettingsList(),
            ],
          ),
        ),
      ),
    );
  }

  // 用户信息卡片
  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // 头像
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF6b4bbd).withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFF6b4bbd),
              size: 30,
            ),
          ),
          const SizedBox(width: 15),

          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '英语学习者',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '继续你的学习之旅',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // 右箭头
          Icon(
            Icons.arrow_forward_ios,
            color: Colors.grey[400],
            size: 16,
          ),
        ],
      ),
    );
  }

  // 功能列表
  Widget _buildFunctionList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 我的收藏
          Obx(() => _buildMenuItem(
                icon: Icons.bookmark,
                title: '我的收藏',
                subtitle: '${bookmarkController.bookmarkCount} 篇文章',
                color: const Color(0xFF6b4bbd),
                onTap: () {
                  log.i('点击我的收藏');
                  Get.to(() => BookmarkPage());
                },
              )),

          _buildDivider(),

          // 学习统计
          _buildMenuItem(
            icon: Icons.bar_chart,
            title: '学习统计',
            subtitle: '查看学习进度',
            color: Colors.orange,
            onTap: () {
              Get.snackbar(
                '功能开发中',
                '学习统计功能即将上线',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
          ),

          _buildDivider(),

          // 学习记录
          _buildMenuItem(
            icon: Icons.history,
            title: '学习记录',
            subtitle: '查看学习历史',
            color: Colors.green,
            onTap: () {
              Get.snackbar(
                '功能开发中',
                '学习记录功能即将上线',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
          ),
        ],
      ),
    );
  }

  // 设置列表
  Widget _buildSettingsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 应用更新
          _buildUpdateMenuItem(),

          _buildDivider(),

          // 安装权限设置
          _buildInstallPermissionMenuItem(),

          _buildDivider(),

          // 设置
          _buildMenuItem(
            icon: Icons.settings,
            title: '设置',
            subtitle: '个性化设置',
            color: Colors.grey[600]!,
            onTap: () {
              Get.snackbar(
                '功能开发中',
                '设置功能即将上线',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
          ),

          _buildDivider(),

          // 帮助与反馈
          _buildMenuItem(
            icon: Icons.help_outline,
            title: '帮助与反馈',
            subtitle: '使用帮助和问题反馈',
            color: Colors.blue,
            onTap: () {
              _showFeedbackDialog();
            },
          ),

          _buildDivider(),

          // 关于
          _buildMenuItem(
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '版本信息',
            color: Colors.teal,
            onTap: () {
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  // 菜单项
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 图标
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),

            // 标题和副标题
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // 右箭头
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // 构建更新菜单项
  Widget _buildUpdateMenuItem() {
    return Obx(() {
      final hasUpdate = updateController.hasUpdate;
      final isChecking = updateController.isCheckingUpdate;
      final isDownloading = updateController.isDownloading;
      final downloadCompleted = updateController.downloadCompleted;
      final currentVersion = updateController.currentVersion;

      // 确定显示状态
      String title;
      String subtitle;
      Color iconColor;
      IconData iconData;
      VoidCallback? onTap;

      if (downloadCompleted) {
        title = '立即安装';
        subtitle = 'APK已下载，点击安装';
        iconColor = Colors.blue;
        iconData = Icons.install_mobile;
        onTap = updateController.installDownloadedAPK;
      } else if (hasUpdate) {
        title = isDownloading ? '下载中...' : '下载更新';
        subtitle = isDownloading
            ? '${updateController.downloadProgress}% - ${updateController.downloadStatus}'
            : '版本 ${updateController.updateInfo?.version ?? ''} 可用';
        iconColor = Colors.orange;
        iconData = Icons.download;
        onTap = isDownloading ? null : updateController.downloadAPK;
      } else {
        title = isChecking ? '检查中...' : '检查更新';
        subtitle = '当前版本：$currentVersion';
        iconColor = Colors.green;
        iconData = Icons.system_update;
        onTap = isChecking ? null : updateController.checkForUpdate;
      }

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 图标
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),

              // 标题和副标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (isChecking || isDownloading)
                          const SizedBox(width: 8),
                        if (isChecking)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(iconColor),
                            ),
                          ),
                        if (isDownloading)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(iconColor),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: downloadCompleted
                            ? Colors.blue[600]
                            : hasUpdate
                                ? Colors.orange[600]
                                : Colors.grey[600],
                      ),
                    ),
                    if (isDownloading && updateController.downloadProgress > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: LinearProgressIndicator(
                          value: updateController.downloadProgress / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      ),
                  ],
                ),
              ),

              // 右箭头或状态图标
              if (downloadCompleted)
                Icon(
                  Icons.play_arrow,
                  color: Colors.blue[600],
                  size: 20,
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
            ],
          ),
        ),
      );
    });
  }

  // 构建安装权限菜单项
  Widget _buildInstallPermissionMenuItem() {
    return Obx(() {
      final canInstall = updateController.canInstall;

      return _buildMenuItem(
        icon: Icons.security,
        title: '安装权限',
        subtitle: canInstall ? '已开启安装未知应用权限' : '需要开启安装未知应用权限',
        color: canInstall ? Colors.green : Colors.orange,
        onTap: () {
          if (canInstall) {
            Get.snackbar(
              '权限状态',
              '安装权限已开启，可以正常安装APK',
              snackPosition: SnackPosition.BOTTOM,
            );
          } else {
            Get.dialog(
              AlertDialog(
                title: const Text('安装权限设置'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前未开启"安装未知应用"权限'),
                    SizedBox(height: 12),
                    Text('开启后可以：'),
                    Text('• 直接安装应用更新'),
                    Text('• 无需每次手动操作'),
                    SizedBox(height: 12),
                    Text('是否现在去设置？'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      updateController.openAppSettings();
                    },
                    child: const Text('去设置'),
                  ),
                ],
              ),
            );
          }
        },
      );
    });
  }

  // 分割线
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        color: Colors.grey[200],
        height: 1,
      ),
    );
  }

  // 显示反馈对话框
  void _showFeedbackDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('帮助与反馈'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('遇到问题或有建议？'),
            const SizedBox(height: 12),

            // 邮件反馈
            InkWell(
              onTap: () {
                Get.back();
                updateController.sendFeedbackEmail();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.email, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('发送邮件反馈', style: TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // GitHub Issues
            InkWell(
              onTap: () {
                Get.back();
                updateController.openGitHubRepo();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('GitHub Issues'),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  // 显示关于对话框
  void _showAboutDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('关于'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 语言助手'),
            const SizedBox(height: 12),
            Obx(() => Text('版本：${updateController.currentVersion}')),
            const SizedBox(height: 12),
            const Text('一个帮助你学习英语的智能助手应用'),
            const SizedBox(height: 12),
            const Text('开发者：Mika'),
            const SizedBox(height: 8),

            // GitHub项目链接
            InkWell(
              onTap: updateController.openGitHubRepo,
              child: const Text(
                'GitHub：https://github.com/Dolores18/mika_app',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 12),

            const Text('📱 应用更新',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('• 在"我的"页面点击"检查更新"'),
            const Text('• 或访问GitHub Release页面'),
            const SizedBox(height: 8),

            // Release页面链接
            Row(
              children: [
                const Text('🔗 Release页面：'),
                const SizedBox(width: 4),
                InkWell(
                  onTap: updateController.openGitHubRelease,
                  child: const Text(
                    '点击访问',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
