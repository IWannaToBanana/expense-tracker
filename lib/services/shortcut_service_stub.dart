/// ShortcutService 的 stub 实现
/// 用于在未安装 receive_sharing_intent 包时提供默认实现
/// 在 iOS 构建时，会被真正的 shortcut_service.dart 替换

class ShortcutService {
  /// 初始化快捷指令监听（stub版本不做任何事）
  void initialize({
    required Function(String imagePath) onImageReceived,
    required Function(dynamic error) onError,
  }) {
    // Stub: 不做任何操作
  }

  /// 处理分享的图片并识别金额（stub版本返回null）
  Future<double?> processSharedImage(String imagePath) async {
    // Stub: 不做任何操作
    return null;
  }

  /// 释放资源
  void dispose() {
    // Stub: 不做任何操作
  }
}
