import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';

class StorageService {
  static const String _transactionsBoxName = 'transactions';
  late Box<Transaction> _transactionsBox;

  // 初始化
  Future<void> init() async {
    _transactionsBox = await Hive.openBox<Transaction>(_transactionsBoxName);
  }

  // 获取所有交易
  List<Transaction> getAllTransactions() {
    return _transactionsBox.values.toList();
  }

  // 按日期获取交易
  List<Transaction> getTransactionsByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _transactionsBox.values.where((transaction) {
      return transaction.date.isAfter(startOfDay) &&
             transaction.date.isBefore(endOfDay);
    }).toList();
  }

  // 获取指定日期范围的交易
  List<Transaction> getTransactionsInRange(DateTime start, DateTime end) {
    return _transactionsBox.values.where((transaction) {
      return transaction.date.isAfter(start) &&
             transaction.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  // 按类型获取交易
  List<Transaction> getTransactionsByType(TransactionType type) {
    return _transactionsBox.values.where((t) => t.type == type).toList();
  }

  // 添加交易
  Future<void> addTransaction(Transaction transaction) async {
    await _transactionsBox.add(transaction);
  }

  // 更新交易
  Future<void> updateTransaction(Transaction transaction) async {
    await transaction.save();
  }

  // 删除交易
  Future<void> deleteTransaction(Transaction transaction) async {
    await transaction.delete();
  }

  // 获取今日支出
  double getTodayExpense() {
    final today = DateTime.now();
    final todayTransactions = getTransactionsByDate(today);
    return todayTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取今日收入
  double getTodayIncome() {
    final today = DateTime.now();
    final todayTransactions = getTransactionsByDate(today);
    return todayTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取本月支出
  double getMonthExpense() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthTransactions = getTransactionsInRange(monthStart, now);
    return monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取本月收入
  double getMonthIncome() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthTransactions = getTransactionsInRange(monthStart, now);
    return monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 按分类统计金额
  Map<String, double> getCategoryAmount(DateTime start, DateTime end, TransactionType type) {
    final transactions = getTransactionsInRange(start, end)
        .where((t) => t.type == type);

    final Map<String, double> categoryAmounts = {};
    for (var transaction in transactions) {
      categoryAmounts[transaction.categoryId] =
          (categoryAmounts[transaction.categoryId] ?? 0) + transaction.amount;
    }
    return categoryAmounts;
  }

  // 清空所有数据
  Future<void> clearAll() async {
    await _transactionsBox.clear();
  }
}
