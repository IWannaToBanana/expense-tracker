import 'dart:io' show Platform;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 引入 MethodChannel
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:uni_links/uni_links.dart';
import 'dart:async';

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

class _ExpenseTrackerAppState extends ConsumerState<ExpenseTrackerApp> with WidgetsBindingObserver {
  StreamSubscription? _sub;
  static const platform = MethodChannel('com.example.expenseTracker/deeplink');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // iOS 平台初始化快捷指令
    _initializeShortcutsIfNeeded();
    
    // 监听运行时的 Deep Link (如快捷指令的 callback URL)
    _initDeepLinkListener();

    // 监听 iOS 原生自己建桥发来的兜底 Deep Link
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final urlString = call.arguments as String?;
        if (urlString != null) {
          final uri = Uri.tryParse(urlString);
          if (uri != null) {
             debugPrint('Received DeepLink from Native Channel: $uri');
            _handleIncomingUri(uri);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 当应用从后台返回前台时，有时 stream 会丢失事件，这里做一个兜底获取
      getInitialUri().then((uri) {
        if (uri != null) {
          // 由于 getInitialUri 总是返回启动时的URI，我们需要确保不重复处理
          // 但由于我们使用了量身定制的无感记账，通常多次传参的概率较低，或者可以在此处加入去重逻辑
          // 为了确保最高到达率，暂时保留处理
        }
      });
    }
  }

  void _initDeepLinkListener() {
    // 处理冷启动时的初始链接 - 读取使用 uni_links 获取的数据
    getInitialUri().then((uri) {
      if (uri != null) {
        _handleIncomingUri(uri);
      }
    }).catchError((err) {
      debugPrint('Failed to get initial uri: $err');
    });

    // 读取自己搭建的 MethodChannel 兜底缓存的冷启动数据 (主要针对 iOS 强杀启动)
    platform.invokeMethod<String>('getInitialUri').then((urlString) {
      if (urlString != null && urlString.isNotEmpty) {
        final uri = Uri.tryParse(urlString);
        if (uri != null) {
          _handleIncomingUri(uri);
        }
      }
    }).catchError((err) {
      debugPrint('Failed to get native initial uri: $err');
    });

    // 监听应用在后台时的链接
    _sub = uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleIncomingUri(uri);
      }
    }, onError: (err) {
      debugPrint('Deep Link Error: $err');
    });
  }

  /// 处理接收到的 URL (处理冷启动或热启动传来的 URL)
  void _handleIncomingUri(Uri uri) {
    // 1. 如果有 amount 参数，无论路径如何，都直接静默记账
    final amountStr = uri.queryParameters['amount'];
    if (amountStr != null) {
      final amount = double.tryParse(amountStr);
      if (amount != null && amount > 0) {
        // 全自动静默记账，默认存入餐饮
        final defaultCategory = Category.expenseCategories.first;
        _saveQuickTransaction(amount, defaultCategory);
        return;
      }
    }

    // 2. 只有带图片的情况走原先的路径处理逻辑
    String path = uri.path;
    if (path.isEmpty && uri.host.isNotEmpty) {
      path = '/${uri.host}';
    }

    if (path == '/add_transaction' || path == '/add' || path == '/ocr') {
      if (uri.queryParameters.isNotEmpty) {
         final imagePath = uri.queryParameters.values.first;
         if (!imagePath.contains('.')) {
           _recognizeAndShowDialog(imagePath);
         }
      } else {
         _autoRecognizeLatestScreenshot();
      }
    }
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
            if (uri != null && uri.queryParameters.isNotEmpty) {
              // 这是一个带有参数的 Deep Link 调用（比如从快捷指令传来金额）
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  _handleIncomingUri(uri!);
                });
              });
              // 返回首页作为底色背景，并在延时后弹窗
              return MaterialPageRoute(
                builder: (context) => const HomePage(),
              );
            } else {
              // 普通的应用内部路由跳转（用户点击了加号）
              return MaterialPageRoute(
                builder: (context) => const AddTransactionPage(),
              );
            }
          case '/ocr':
            // 通过URL传递图片路径的OCR请求
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (uri != null) {
                   _handleIncomingUri(uri!);
                }
              });
            });
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
