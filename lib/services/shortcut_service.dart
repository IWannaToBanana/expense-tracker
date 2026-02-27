import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'ocr_service.dart';

/// iOS 快捷指令服务
/// 用于接收从快捷指令分享的图片，并进行 OCR 识别
class ShortcutService {
  final OCRService _ocrService = OCRService();

  Stream<List<SharedMediaFile>>? _mediaStream;

  /// 初始化快捷指令监听
  /// 当用户通过快捷指令分享图片到 App 时，会通过此回调通知
  void initialize({
    required Function(String imagePath) onImageReceived,
    required Function(dynamic error) onError,
  }) {
    // 监听分享的媒体文件（图片）
    _mediaStream = ReceiveSharingIntent.instance.getMediaStream();

    _mediaStream!.listen(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) {
          final file = files.first;
          // 由于 Info.plist 已配置只接收图片，直接处理即可
          onImageReceived(file.path);
        }
      },
      onError: onError,
    );

    // 检查 App 启动时是否有待处理的分享内容
    _checkInitialIntent(onImageReceived);
  }

  /// 检查 App 启动时的初始分享意图
  Future<void> _checkInitialIntent(
    Function(String imagePath) onImageReceived,
  ) async {
    try {
      final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initialMedia.isNotEmpty) {
        final file = initialMedia.first;
        // 由于 Info.plist 已配置只接收图片，直接处理即可
        onImageReceived(file.path);
      }
    } catch (e) {
      debugPrint('检查初始分享意图失败: $e');
    }
  }

  /// 处理分享的图片并识别金额
  /// 返回识别到的金额，如果识别失败则返回 null
  Future<double?> processSharedImage(String imagePath) async {
    try {
      return await _ocrService.recognizeAmount(imagePath);
    } catch (e) {
      debugPrint('处理分享图片失败: $e');
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    _mediaStream?.drain();
    _ocrService.dispose();
  }
}
