import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

// 当前选中的Tab索引
final currentTabProvider = StateProvider<int>((ref) => 0);

// 数据变化通知 Provider
final dataChangeNotifierProvider = StateProvider<int>((ref) => 0);

// StorageService Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized in main()');
});
