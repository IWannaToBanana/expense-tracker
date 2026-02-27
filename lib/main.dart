import 'dart:io' show Platform;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'models/transaction.dart';
import 'models/category.dart';
import 'providers/providers.dart';
import 'services/storage_service.dart';
import 'services/shortcut_service.dart';
import 'services/ocr_service.dart';
import 'views/home/home_page.dart';
import 'views/transaction/add_transaction_page.dart';
import 'theme/app_theme.dart';

// 全局导航 key，用于从快捷指令服务中导航
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// URL Scheme 处理
const String _scheme = 'expense-tracker';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive
  await Hive.initFlutter();
  Hive.registerAdapter(TransactionTypeAdapter());
  Hive.registerAdapter(TransactionAdapter());

  // 创建 StorageService 实例
  final storageService = StorageService();
  await storageService.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const ExpenseTrackerApp(),
    ),
  );
}

class ExpenseTrackerApp extends ConsumerStatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  ConsumerState<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends ConsumerState<ExpenseTrackerApp> {
  @override
  void initState() {
    super.initState();
    // iOS 平台初始化快捷指令
    _initializeShortcutsIfNeeded();
  }

  /// 自动识别最新截图并显示确认弹窗
  void _autoRecognizeLatestScreenshot() async {
    try {
      final ImagePicker picker = ImagePicker();
      final OCRService ocrService = OCRService();

      // 打开相册选择图片
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        _showSnackBar('正在识别金额...');

        final amount = await ocrService.recognizeAmount(image.path);

        if (amount != null && mounted) {
          // 显示确认弹窗
          _showQuickAddDialog(amount);
        } else if (mounted) {
          _showSnackBar('未能识别金额', isError: true);
        }
      }

      ocrService.dispose();
    } catch (e) {
      debugPrint('自动识别失败: $e');
    }
  }

  /// 识别指定路径的图片并显示确认弹窗
  void _recognizeAndShowDialog(String imagePath) async {
    try {
      final OCRService ocrService = OCRService();

      _showSnackBar('正在识别金额...');

      final amount = await ocrService.recognizeAmount(imagePath);

      if (amount != null && mounted) {
        _showQuickAddDialog(amount);
      } else if (mounted) {
        _showSnackBar('未能识别金额', isError: true);
      }

      ocrService.dispose();
    } catch (e) {
      debugPrint('OCR识别失败: $e');
      if (mounted) {
        _showSnackBar('识别失败: $e', isError: true);
      }
    }
  }

  /// 显示快速记账弹窗
  void _showQuickAddDialog(double amount) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // 默认分类（餐饮）
    Category selectedCategory = Category.expenseCategories.first;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('确认记账'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 金额显示
              Text(
                '¥${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.expense,
                ),
              ),
              const SizedBox(height: 20),

              // 分类选择
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('分类', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Category.expenseCategories.take(6).map((cat) {
                  final isSelected = selectedCategory.id == cat.id;
                  return InkWell(
                    onTap: () {
                      setDialogState(() {
                        selectedCategory = cat;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.expense : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            cat.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _saveQuickTransaction(amount, selectedCategory);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
              ),
              child: const Text('确认记账'),
            ),
          ],
        ),
      ),
    );
  }

  /// 快速保存交易
  Future<void> _saveQuickTransaction(double amount, Category category) async {
    try {
      final storageService = ref.read(storageServiceProvider);
      final transaction = Transaction.create(
        amount: amount,
        categoryId: category.id,
        categoryName: category.name,
        categoryIcon: category.icon,
        categoryColor: category.color,
        date: DateTime.now(),
        type: TransactionType.expense,
      );

      await storageService.addTransaction(transaction);

      if (mounted) {
        ref.read(dataChangeNotifierProvider.notifier).state++;
        _showSnackBar('已记账 ¥${amount.toStringAsFixed(2)}');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('记账失败: $e', isError: true);
      }
    }
  }

  void _initializeShortcutsIfNeeded() {
    // iOS 平台初始化快捷指令
    if (Platform.isIOS) {
      final shortcutService = ShortcutService();
      shortcutService.initialize(
        onImageReceived: (imagePath) async {
          _showSnackBar('正在识别金额...');
          final amount = await shortcutService.processSharedImage(imagePath);
          if (amount != null) {
            navigatorKey.currentState?.pushNamed(
              '/add_transaction',
              arguments: amount,
            );
            _showSnackBar('识别到金额: ¥${amount.toStringAsFixed(2)}');
          } else {
            navigatorKey.currentState?.pushNamed('/add_transaction');
            _showSnackBar('未能识别金额，请手动输入', isError: true);
          }
        },
        onError: (error) {
          _showSnackBar('快捷指令错误: $error', isError: true);
        },
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '记账助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      onGenerateRoute: (settings) {
        // 解析 URL 路径（去掉 scheme）
        String path = settings.name ?? '/';
        if (path.startsWith('expense-tracker://')) {
          path = path.replaceFirst('expense-tracker://', '/');
        } else if (path.contains('://')) {
          // 处理其他可能的 URL schemes
          final schemeEnd = path.indexOf('://');
          path = path.substring(schemeEnd + 3);
          if (!path.startsWith('/')) {
            path = '/$path';
          }
        }

        // 解析查询参数（图片路径）
        Uri? uri;
        if (settings.name != null && settings.name!.contains('?')) {
          uri = Uri.parse(settings.name!);
        }

        switch (path) {
          case '/add_transaction':
          case '/add':
            // 触发快速记账流程（延迟执行，等待页面加载完成）
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 300), () {
                // 检查是否有amount参数（快捷指令OCR识别的金额）
                final amountStr = uri?.queryParameters['amount'];
                if (amountStr != null) {
                  final amount = double.tryParse(amountStr);
                  if (amount != null && amount > 0) {
                    _showQuickAddDialog(amount);
                    return;
                  }
                }

                // 如果有图片路径参数，直接OCR
                if (uri?.queryParameters.isNotEmpty == true) {
                  final imagePath = uri?.queryParameters.values.first;
                  if (imagePath != null && !imagePath.contains('.')) {
                    _recognizeAndShowDialog(imagePath);
                    return;
                  }
                }

                // 否则弹出相册选择
                _autoRecognizeLatestScreenshot();
              });
            });
            // 返回首页作为背景
            return MaterialPageRoute(
              builder: (context) => const HomePage(),
            );
          case '/ocr':
            // 通过URL传递图片路径的OCR请求
            if (uri?.queryParameters.isNotEmpty == true) {
              final imagePath = uri?.queryParameters.values.first;
              if (imagePath != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _recognizeAndShowDialog(imagePath);
                  });
                });
              }
            }
            return MaterialPageRoute(
              builder: (context) => const HomePage(),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const HomePage(),
            );
        }
      },
      home: const HomePage(),
    );
  }
}
