import 'transaction.dart';

class CategoryStatistics {
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final double amount;
  final double percentage;
  final int count;

  CategoryStatistics({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.amount,
    required this.percentage,
    required this.count,
  });
}

class MonthlyStatistics {
  final double totalExpense;
  final double totalIncome;
  final double balance;
  final List<CategoryStatistics> expenseByCategory;
  final List<CategoryStatistics> incomeByCategory;
  final List<Transaction> transactions;

  MonthlyStatistics({
    required this.totalExpense,
    required this.totalIncome,
    required this.balance,
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.transactions,
  });
}

class DailyStatistics {
  final double expense;
  final double income;
  final int transactionCount;
  final List<Transaction> transactions;

  DailyStatistics({
    required this.expense,
    required this.income,
    required this.transactionCount,
    required this.transactions,
  });
}
