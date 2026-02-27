import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 1)
class Transaction extends HiveObject {
  @HiveField(0)
  late double amount;

  @HiveField(1)
  late String categoryId;

  @HiveField(2)
  late String categoryName;

  @HiveField(3)
  late String categoryIcon;

  @HiveField(4)
  late String categoryColor;

  @HiveField(5)
  String? note;

  @HiveField(6)
  late DateTime date;

  @HiveField(7)
  late TransactionType type;

  Transaction();

  Transaction.create({
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    this.note,
    required this.date,
    required this.type,
  });
}

@HiveType(typeId: 2)
enum TransactionType {
  @HiveField(0)
  expense,
  @HiveField(1)
  income;

  String get displayName {
    switch (this) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
    }
  }
}
