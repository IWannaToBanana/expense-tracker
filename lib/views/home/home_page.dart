import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/transaction.dart';
import '../../../providers/providers.dart';
import '../../../services/storage_service.dart';
import '../../../theme/app_theme.dart';
import '../transaction/transaction_list_page.dart';
import '../statistics/charts_page.dart';
import '../../widgets/stat_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(currentTabProvider);

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: currentTab,
          children: const [
            _StatisticsTab(),
            TransactionListPage(),
            ChartsPage(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab,
        onTap: (index) {
          ref.read(currentTabProvider.notifier).state = index;
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '统计',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_outlined),
            activeIcon: Icon(Icons.list),
            label: '账目',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            activeIcon: Icon(Icons.pie_chart),
            label: '图表',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add_transaction');
          // 返回后刷新数据
          if (mounted) {
            ref.read(dataChangeNotifierProvider.notifier).state++;
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatisticsTab extends ConsumerWidget {
  const _StatisticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageService = ref.watch(storageServiceProvider);
    final _ = ref.watch(dataChangeNotifierProvider); // 监听数据变化

    final now = DateTime.now();
    final todayExpense = storageService.getTodayExpense();
    final todayIncome = storageService.getTodayIncome();
    final monthExpense = storageService.getMonthExpense();
    final monthIncome = storageService.getMonthIncome();
    final balance = monthIncome - monthExpense;

    // 获取最近的交易
    final allTransactions = storageService.getAllTransactions();
    allTransactions.sort((a, b) => b.date.compareTo(a.date));
    final recentTransactions = allTransactions.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部标题和月份选择
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '记账助手',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).dividerTheme.color!,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      DateFormat('yyyy年MM月').format(now),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 今日支出卡片
          StatCard(
            title: '今日支出',
            amount: todayExpense,
            subtitle: '共 ${storageService.getTransactionsByDate(now).length} 笔',
            color: AppColors.expense,
            icon: Icons.today_outlined,
          ),

          const SizedBox(height: 16),

          // 统计网格
          Row(
            children: [
              Expanded(
                child: _StatGridCard(
                  title: '本月支出',
                  amount: monthExpense,
                  color: AppColors.expense,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatGridCard(
                  title: '本月收入',
                  amount: monthIncome,
                  color: AppColors.income,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 结余卡片
          _StatGridCard(
            title: '本月结余',
            amount: balance,
            color: balance >= 0 ? AppColors.income : AppColors.expense,
            fullWidth: true,
          ),

          const SizedBox(height: 24),

          // 最近交易
          Text(
            '最近交易',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          _RecentTransactionList(transactions: recentTransactions),
        ],
      ),
    );
  }
}

class _StatGridCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final bool fullWidth;

  const _StatGridCard({
    required this.title,
    required this.amount,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: color,
                  fontSize: 24,
                ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionList extends StatelessWidget {
  final List<Transaction> transactions;

  const _RecentTransactionList({required this.transactions, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            '暂无交易记录\n点击右下角 + 添加第一笔',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      );
    }

    return Column(
      children: transactions.map((transaction) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color!,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorFromHex(transaction.categoryColor).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    transaction.categoryIcon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.categoryName,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      _formatTime(transaction.date),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Text(
                '${transaction.type == TransactionType.expense ? '-' : '+'}¥${transaction.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: transaction.type == TransactionType.expense
                          ? AppColors.expense
                          : AppColors.income,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDay = DateTime(date.year, date.month, date.day);

    if (transactionDay == today) {
      return DateFormat('HH:mm').format(date);
    } else if (transactionDay == today.subtract(const Duration(days: 1))) {
      return '昨天';
    } else {
      return DateFormat('MM月dd日').format(date);
    }
  }

  Color colorFromHex(String hexColor) {
    final hex = hexColor.replaceAll('#', '').substring(2);
    return Color(int.parse('FF$hex', radix: 16));
  }
}
