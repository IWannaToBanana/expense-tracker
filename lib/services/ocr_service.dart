import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR金额识别服务
/// 用于从支付截图中提取金额信息
class OCRService {
  final textRecognizer = TextRecognizer();

  /// 从图片路径识别金额
  /// 返回识别到的金额，如果未识别到则返回null
  Future<double?> recognizeAmount(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      // 从识别文本中提取金额
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final amount = _extractAmount(line.text);
          if (amount != null && amount > 0) {
            return amount;
          }
        }
      }

      // 如果没找到，尝试直接从文本中查找
      return _extractAmountFromText(recognizedText.text);
    } catch (e) {
      print('OCR识别失败: $e');
      return null;
    }
  }

  /// 从单行文本中提取金额
  double? _extractAmount(String text) {
    // 移除空格
    text = text.replaceAll(' ', '');

    // 匹配模式：¥123.45, ￥123.45, $123.45, 123.45元, 123.45, 等
    final patterns = [
      RegExp(r'[¥￥]\s*(\d+\.?\d{0,2})'), // ¥123.45
      RegExp(r'\$\s*(\d+\.?\d{0,2})'), // $123.45
      RegExp(r'(\d+\.?\d{0,2})\s*元'), // 123.45元
      RegExp(r'(\d{1,6}\.\d{2})'), // 123.45 (必须是两位小数)
      RegExp(r'(\d{1,6})'), // 纯数字
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1);
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0 && amount < 1000000) {
            // 过滤掉不合理的金额（0元或过大金额）
            return amount;
          }
        }
      }
    }

    return null;
  }

  /// 从完整文本中提取最可能的金额
  double? _extractAmountFromText(String fullText) {
    // 按行分割
    final lines = fullText.split('\n');

    // 常见的支付关键词附近可能有金额
    final keywords = ['付款', '支付', '金额', '合计', '总计', '实付', '微信', '支付宝', 'QQ', '元'];

    for (var line in lines) {
      for (var keyword in keywords) {
        if (line.contains(keyword)) {
          final amount = _extractAmount(line);
          if (amount != null) {
            return amount;
          }
        }
      }
    }

    // 如果没找到关键词匹配，返回最大的合理金额
    double? maxAmount;
    for (var line in lines) {
      final amount = _extractAmount(line);
      if (amount != null) {
        if (maxAmount == null || amount > maxAmount) {
          maxAmount = amount;
        }
      }
    }

    return maxAmount;
  }

  /// 释放资源
  void dispose() {
    textRecognizer.close();
  }
}
