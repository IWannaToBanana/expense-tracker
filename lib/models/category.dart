import 'transaction.dart';

class Category {
  final String id;
  final String name;
  final String icon;
  final String color;
  final TransactionType type;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  // 支出分类
  static const List<Category> expenseCategories = [
    Category(
      id: '1',
      name: '餐饮',
      icon: '🍜',
      color: '#FFFF6B6B',
      type: TransactionType.expense,
    ),
    Category(
      id: '2',
      name: '交通',
      icon: '🚗',
      color: '#FF4ECDC4',
      type: TransactionType.expense,
    ),
    Category(
      id: '3',
      name: '购物',
      icon: '🛍️',
      color: '#FF45B7D1',
      type: TransactionType.expense,
    ),
    Category(
      id: '4',
      name: '游戏',
      icon: '🎮',
      color: '#FF96CEB4',
      type: TransactionType.expense,
    ),
    Category(
      id: '5',
      name: '娱乐',
      icon: '🎬',
      color: '#FFFFEAA7',
      type: TransactionType.expense,
    ),
    Category(
      id: '6',
      name: '医疗',
      icon: '💊',
      color: '#FFDDA0DD',
      type: TransactionType.expense,
    ),
    Category(
      id: '7',
      name: '教育',
      icon: '📚',
      color: '#FF98D8C8',
      type: TransactionType.expense,
    ),
    Category(
      id: '8',
      name: '其他',
      icon: '📦',
      color: '#FF95A5A6',
      type: TransactionType.expense,
    ),
  ];

  // 收入分类
  static const List<Category> incomeCategories = [
    Category(
      id: '101',
      name: '工资',
      icon: '💰',
      color: '#FF2ECC71',
      type: TransactionType.income,
    ),
    Category(
      id: '102',
      name: '奖金',
      icon: '🎁',
      color: '#FF3498DB',
      type: TransactionType.income,
    ),
    Category(
      id: '103',
      name: '理财',
      icon: '📈',
      color: '#FF9B59B6',
      type: TransactionType.income,
    ),
    Category(
      id: '104',
      name: '其他',
      icon: '📦',
      color: '#FF95A5A6',
      type: TransactionType.income,
    ),
  ];

  // 获取所有分类
  static List<Category> getAllCategories() {
    return [...expenseCategories, ...incomeCategories];
  }

  // 根据ID获取分类
  static Category? getCategoryById(String id) {
    try {
      return getAllCategories().firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // 根据类型获取分类
  static List<Category> getCategoriesByType(TransactionType type) {
    return getAllCategories().where((c) => c.type == type).toList();
  }
}
