# iOS 云端构建指南

由于没有 Mac，可以使用以下云端服务构建 iOS 版本。

---

## 方案一：GitHub Actions（推荐）

### 1. 推送代码到 GitHub

```bash
cd D:\Project\ExpenseTracker
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/你的用户名/expense-tracker.git
git push -u origin main
```

### 2. 触发构建

推送代码后，GitHub Actions 会自动开始构建 iOS 版本。

### 3. 下载构建产物

1. 访问 https://github.com/你的用户名/expense-tracker/actions
2. 点击最新的 workflow run
3. 在 "Artifacts" 区域下载 `ios-build`
4. 解压后得到 `Runner.app`

### 4. 安装到 iPhone

```bash
# 方法 1: 使用 ios-deploy
brew install ios-deploy
ios-deploy --bundle Runner.app

# 方法 2: 使用 Apple Configurator (macOS)
# 将 iPhone 连接到 Mac，用 Apple Configurator 安装

# 方法 3: 使用 AltStore (无需 Mac)
# 在 iPhone 上安装 AltStore，然后通过 WiFi 安装
```

---

## 方案二：Codemagic

### 步骤

1. 访问 https://codemagic.io/
2. 用 GitHub 账号登录
3. 选择你的仓库
4. 配置构建：
   - Flutter version: 3.24.5
   - Build type: Release
   - iOS code signing: Off (用于个人测试)
5. 开始构建
6. 下载 .ipa 文件
7. 用 AltStore 安装到 iPhone

---

## 方案三：Bitrise

### 步骤

1. 访问 https://www.bitrise.io/
2. 用 GitHub 账号登录
3. 添加新 App
4. 选择 Starter 计划（免费）
5. 配置 workflow：
   ```yaml
   workflows:
     primary:
       steps:
         - activate-ssh-key
         - git-clone
         - flutter-installer
         - flutter-build:
             inputs:
               project_location: "$BITRISE_SOURCE_DIR"
               ios_code_signing: off
         - deploy-to-bitrise-io
   ```
6. 启动构建
7. 下载安装包

---

## 方案四：Appcircle

### 步骤

1. 访问 https://appcircle.io/
2. 免费注册
3. 连接 GitHub 仓库
4. 选择 Flutter 项目
5. 自动开始构建
6. 下载 .ipa 文件

---

## 方案五：Xcode Cloud（需要 Apple ID）

### 步骤

1. 将代码推送到 GitHub
2. 在 Xcode (需要 Mac) 或 https://appstoreconnect.apple.com/ 配置
3. 创建 App Store Connect App
4. 启用 Xcode Cloud
5. 添加仓库并配置 workflow
6. 自动构建并发布到 TestFlight

---

## 安装到 iPhone（无需 Mac）

### 使用 AltStore

1. 在 iPhone 上安装 AltStore (https://altstore.io/)
2. 电脑上安装 AltServer
3. 下载构建的 .ipa 文件
4. 用 AltStore 打开 .ipa 文件
5. 输入 Apple ID 安装

### 使用 Sideloadly

1. 下载 Sideloadly (Windows/Mac)
2. 连接 iPhone 到电脑
3. 用 Sideloadly 打开 .ipa 文件
4. 输入 Apple ID
5. 点击 Install

---

## iOS 快捷指令设置（构建后）

1. 将构建的 App 安装到 iPhone
2. 打开 iPhone **设置** → **辅助功能** → **触控** → **轻点背面**
3. 选择 **轻点两下** → **创建新快捷指令**
4. 添加操作：
   - **截图**
   - **共享** → 选择 **记账助手**
5. 完成！现在双击手机背部即可触发记账

---

## 快捷测试（GitHub Actions + TestFlight）

如果要发布到 App Store，需要：

1. Apple Developer 账号 ($99/年)
2. 在 App Store Connect 创建 App
3. 配置 GitHub Actions secrets：
   - `APPSTORE_ISSUER_ID`
   - `APPSTORE_API_KEY_ID`
   - `APPSTORE_API_PRIVATE_KEY`
4. 取消注释 `.github/workflows/ios.yml` 中的 TestFlight 步骤
5. 推送代码，自动发布到 TestFlight
6. 在 TestFlight 测试
