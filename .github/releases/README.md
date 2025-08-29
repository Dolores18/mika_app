# 📱 Mika App 自动构建版本

这个目录包含自动构建的最新APK文件，方便Android用户直接下载。

## 🔗 下载链接

### 最新版本APK（固定链接）
```
https://github.com/Dolores18/mika_app/raw/use_html/.github/releases/mika-app-latest.apk
```

### 版本信息API
```
https://github.com/Dolores18/mika_app/raw/use_html/.github/releases/version.json
```

## 📋 文件说明

- **`mika-app-latest.apk`** - 最新版本的Android APK文件（每次CI构建时自动覆盖）
- **`version.json`** - 版本信息，包含版本号、构建时间、提交hash等
- **`README.md`** - 本说明文件

## 🚀 更新机制

1. 开发者推送代码到 `use_html` 分支
2. GitHub Actions 自动触发构建
3. 构建完成后自动覆盖此目录下的APK文件
4. 用户始终可以通过固定链接下载最新版本

## 💡 使用建议

- **收藏下载链接**：用户可以收藏APK下载链接，每次想更新时直接访问
- **版本检查**：应用可以通过访问 `version.json` 来检查是否有新版本
- **自动更新**：可以在应用内实现检查更新功能

## 🔐 安全提醒

- 请确保从官方仓库下载APK
- 建议启用Android的"未知来源"应用安装权限
- 如有疑问，请查看源代码确认安全性
