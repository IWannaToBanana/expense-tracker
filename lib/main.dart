import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/transaction.dart';
import 'providers/providers.dart';
import 'services/storage_service.dart';
import 'services/shortcut_service.dart';
import 'views/home/home_page.dart';
import 'views/transaction/add_transaction_page.dart';
import 'theme/app_theme.dart';

// 全局导航 key，用于从快捷指令服务中导航
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        switch (settings.name) {
          case '/add_transaction':
            // 支持两种参数类型：Transaction（编辑）或 double（OCR识别金额）
            if (settings.arguments is Transaction) {
              return MaterialPageRoute(
                builder: (context) => AddTransactionPage(
                  transaction: settings.arguments as Transaction?,
                ),
              );
            } else if (settings.arguments is double) {
              return MaterialPageRoute(
                builder: (context) => AddTransactionPage(
                  initialAmount: settings.arguments as double?,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (context) => const AddTransactionPage(),
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
