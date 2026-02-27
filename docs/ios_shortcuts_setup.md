# iOS 快捷指令集成说明

## 功能说明

iOS 快捷指令允许用户通过双击手机背部（或 Siri 语音）触发截图，然后自动识别金额并快速记账。

## 体验要求

- iOS 14+ 系统
- 已安装记账助手 App

## 用户设置步骤

### 方法一：双击背部触发（推荐）

1. 打开 iPhone **设置** → **辅助功能** → **触控**
2. 滑动到底部，点击 **轻点背面**
3. 选择 **轻点两下** 或 **轻点三下**
4. 选择 **创建新快捷指令**
5. 在快捷指令 App 中编辑：
   - 添加操作：**截图**
   - 添加操作：**共享** → 选择 **记账助手**
   - 添加操作：**打开记账助手**

### 方法二：从相册分享

1. 打开 **照片** App
2. 选择一张支付截图
3. 点击左下角 **分享** 按钮
4. 选择 **记账助手**
5. 自动识别金额并跳转到记账页面

### 方法三：Siri 语音触发

1. 打开 **快捷指令** App
2. 创建新快捷指令，命名为"记一笔"
3. 添加操作：
   - **截图**
   - **共享** → **记账助手**
   - **打开记账助手**
4. 点击右上角 **i** 按钮 → 添加到 Siri
5. 录录语音指令（如"记一笔"）
6. 对 Siri 说"记一笔"即可触发

## 开发者配置

### Info.plist 配置

已在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>1</integer>
        </dict>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

### Flutter 代码实现

- **main.dart**: 初始化 ShortcutService，监听分享的图片
- **services/shortcut_service.dart**: 处理分享意图，调用 OCR 识别
- **services/ocr_service.dart**: 从图片中识别金额

### iOS 原生配置

由于使用了 `receive_sharing_intent` 插件，以下配置自动完成：

1. `ios/Runner/Runner-Bridging-Header.h` - 自动生成
2. URL Scheme 配置 - 自动添加

## 测试

### 模拟器测试
模拟器无法测试双击背部，但可以测试分享功能：

1. 在模拟器中保存一张支付截图到相册
2. 从照片 App 分享图片到记账助手
3. 验证是否正确跳转并识别金额

### 真机测试
1. 在真机上安装 App
2. 按照上述方法设置双击背部
3. 双击手机背部触发
4. 验证是否自动识别金额并跳转

## 故障排除

### 问题：快捷指令中找不到记账助手
**解决**：确保 App 已在真机上运行过至少一次

### 问题：分享后没有跳转
**解决**：
1. 检查 Info.plist 配置是否正确
2. 重新构建 App：`flutter clean && flutter build ios`

### 问题：识别金额失败
**解决**：
1. 确保截图清晰，金额文字完整可见
2. 截图应包含支付关键词（付款、金额、¥、元等）
3. 尝试手动选择相册识别功能

## 支持的支付截图

OCR 功能支持识别以下类型的截图：

- 微信支付截图
- 支付宝支付截图
- QQ 钱包截图
- 银行卡支付截图
- 任何包含金额数字的图片

## 后续扩展

可以考虑添加的功能：

1. 自动识别分类（根据商家名称）
2. 自动填写备注（提取商家、时间等信息）
3. iCloud 同步交易数据
4. Widget 快捷记账小组件
