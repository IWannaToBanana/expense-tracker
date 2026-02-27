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

      // 调试：打印所有识别的文本
      print('=== OCR 识别结果 ===');
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          print('行: ${line.text}');
        }
      }
      print('==================');

      // 从识别文本中提取金额
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final amount = _extractAmount(line.text);
          if (amount != null && amount > 0) {
            print('✓ 从行识别到金额: $amount (原文: ${line.text})');
            return amount;
          }
        }
      }

      // 如果没找到，尝试直接从文本中查找
      final amount = _extractAmountFromText(recognizedText.text);
      if (amount != null) {
        print('✓ 从全文识别到金额: $amount');
      } else {
        print('✗ 未识别到金额');
      }
      return amount;
    } catch (e) {
      print('OCR识别失败: $e');
      return null;
    }
  }

  /// 从单行文本中提取金额
  /// priority: 金额符号在前 > 金额单位在后 > 带小数点 > 纯数字
  double? _extractAmount(String text, {bool requireSymbol = false}) {
    // 移除空格
    text = text.replaceAll(' ', '');

    // 匹配模式：¥123.45, ￥123.45, $123.45, 123.45元, 123.45, 等
    final patterns = [
      // 高优先级：带金额符号的（¥/￥）
      RegExp(r'[¥￥]\s*(\d+\.\d{1,2})'), // ¥123.45 或 ¥123.4
      RegExp(r'[¥￥]\s*(\d+)'), // ¥123

      // 中等优先级：带金额单位的（元）
      RegExp(r'(\d+\.\d{1,2})\s*元'), // 123.45元
      RegExp(r'(\d+)\s*元'), // 123元

      // 低优先级：纯小数（可能是金额，也可能是其他数字）
      RegExp(r'(\d+\.\d{2})'), // 123.45 (两位小数)
      RegExp(r'(\d+\.\d{1})'), // 123.4 (一位小数)

      // 最低优先级：纯数字（仅在不要求符号时使用）
      if (!requireSymbol) RegExp(r'(\d{2,})'), // 至少两位数字，过滤掉单个数字
    ];

    for (var pattern in patterns) {
      if (pattern == null) continue;
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1);
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0 && amount < 1000000) {
            // 过滤掉不合理的金额（0元或过大金额）
            // 过滤掉明显不是金额的数字（如小时、分钟）
            if (amount < 24 && !text.contains('元') && !text.contains('¥') && !text.contains('￥')) {
              // 小于24的数字且没有金额符号，可能是时间，跳过
              continue;
            }
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

    // 第一优先级：查找带金额符号（¥/￥）且有关键词的行
    final keywords = ['付款', '支付', '金额', '合计', '总计', '实付', '收款', '转账', '费用'];

    for (var line in lines) {
      // 检查是否包含金额符号
      if (line.contains('¥') || line.contains('￥')) {
        for (var keyword in keywords) {
          if (line.contains(keyword)) {
            final amount = _extractAmount(line, requireSymbol: false);
            if (amount != null && amount >= 0.01) {
              return amount;
            }
          }
        }
      }
    }

    // 第二优先级：查找带金额符号的行（无论是否有关键词）
    for (var line in lines) {
      if (line.contains('¥') || line.contains('￥')) {
        final amount = _extractAmount(line, requireSymbol: false);
        if (amount != null && amount >= 0.01) {
          return amount;
        }
      }
    }

    // 第三优先级：查找带"元"且有关键词的行
    for (var line in lines) {
      if (line.contains('元')) {
        for (var keyword in keywords) {
          if (line.contains(keyword)) {
            final amount = _extractAmount(line, requireSymbol: false);
            if (amount != null && amount >= 0.01) {
              return amount;
            }
          }
        }
      }
    }

    // 第四优先级：查找带"元"的行
    for (var line in lines) {
      if (line.contains('元')) {
        final amount = _extractAmount(line, requireSymbol: false);
        if (amount != null && amount >= 0.01) {
          return amount;
        }
      }
    }

    // 第五优先级：查找带两位小数的数字（可能是金额）
    List<MapEntry<double, String>> decimalAmounts = [];
    for (var line in lines) {
      final match = RegExp(r'(\d+\.\d{2})').firstMatch(line);
      if (match != null) {
        final amount = double.tryParse(match.group(1)!);
        if (amount != null && amount >= 0.01 && amount < 1000000) {
          decimalAmounts.add(MapEntry(amount, line));
        }
      }
    }

    // 如果找到多个小数金额，选择最大值（通常是支付金额）
    if (decimalAmounts.isNotEmpty) {
      decimalAmounts.sort((a, b) => b.key.compareTo(a.key));
      return decimalAmounts.first.key;
    }

    // 最后兜底：所有行中查找最大金额（排除明显过小的数字）
    double? maxAmount;
    for (var line in lines) {
      final amount = _extractAmount(line, requireSymbol: false);
      if (amount != null && amount >= 10) { // 至少10元才考虑
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
