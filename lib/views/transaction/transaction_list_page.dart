import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../../../models/transaction.dart';
import '../../../providers/providers.dart';
import '../../../services/storage_service.dart';

class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({super.key});

  @override
  ConsumerState<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  @override
  Widget build(BuildContext context) {
    final storageService = ref.watch(storageServiceProvider);
    final _ = ref.watch(dataChangeNotifierProvider); // 监听数据变化

    // 获取所有交易并按日期分组
    final allTransactions = storageService.getAllTransactions();
    allTransactions.sort((a, b) => b.date.compareTo(a.date));

    // 按日期分组
    final groupedTransactions = _groupByDate(allTransactions);

    return SafeArea(
      child: Column(
        children: [
          // 顶部标题
          _buildHeader(),

          // 交易列表
          Expanded(
            child: groupedTransactions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: groupedTransactions.length,
                    itemBuilder: (context, index) {
                      final date = groupedTransactions.keys.elementAt(index);
                      final transactions = groupedTransactions[date]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 日期头部
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              date,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ),

                          // 交易卡片列表
                          ...transactions.map((transaction) {
                            return _DismissibleTransactionCard(
                              transaction: transaction,
                              onDelete: () async {
                                await storageService.deleteTransaction(transaction);
                                if (mounted) {
                                  ref.read(dataChangeNotifierProvider.notifier).state++;
                                }
                              },
                              onTap: () {
                                _showEditDialog(context, transaction);
                              },
                            );
                          }).toList(),

                          if (index < groupedTransactions.length - 1)
                            const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerTheme.color!,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '账目明细',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 搜索功能
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无交易记录',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角 + 添加第一笔',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // 按日期分组交易
  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final Map<String, List<Transaction>> grouped = {};
    final now = DateTime.now();

    for (var transaction in transactions) {
      String dateKey;
      final transactionDay = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (transactionDay == today) {
        dateKey = '今天';
      } else if (transactionDay == yesterday) {
        dateKey = '昨天';
      } else {
        dateKey = '${transaction.date.month}月${transaction.date.day}日';
      }

      grouped.putIfAbsent(dateKey, () => []).add(transaction);
    }

    return grouped;
  }

  void _showEditDialog(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditBottomSheet(
        transaction: transaction,
        storageService: ref.read(storageServiceProvider),
      ),
    );
  }
}

class _DismissibleTransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _DismissibleTransactionCard({
    required this.transaction,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final amountColor = isExpense ? AppColors.expense : AppColors.income;
    final amountPrefix = isExpense ? '-' : '+';

    return Dismissible(
      key: ValueKey(transaction.key),
      background: Container(
        color: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 8),
            Text('删除', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        onDelete();
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
              // 分类图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: amountColor.withOpacity(0.15),
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

              // 分类名称和时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.categoryName,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      DateFormat('HH:mm').format(transaction.date),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (transaction.note != null && transaction.note!.isNotEmpty)
                      Text(
                        transaction.note!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // 金额
              Text(
                '$amountPrefix¥${transaction.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 编辑底部弹窗
class _EditBottomSheet extends ConsumerWidget {
  final Transaction transaction;
  final StorageService storageService;

  const _EditBottomSheet({
    required this.transaction,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Row(
              children: [
                const Text(
                  '编辑账目',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 账目详情
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (transaction.type == TransactionType.expense ? AppColors.expense : AppColors.income).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      transaction.categoryIcon,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.categoryName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        DateFormat('yyyy年MM月dd日 HH:mm').format(transaction.date),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (transaction.note != null && transaction.note!.isNotEmpty)
                        Text(
                          transaction.note!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${transaction.type == TransactionType.expense ? '-' : '+'}¥${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: transaction.type == TransactionType.expense ? AppColors.expense : AppColors.income,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // 关闭底部弹窗
                      Navigator.pushNamed(
                        context,
                        '/add_transaction',
                        arguments: transaction, // 传递交易对象用于编辑
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('编辑'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // 删除确认
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('删除账目'),
                          content: const Text('确定要删除这笔账目吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('删除', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await storageService.deleteTransaction(transaction);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ref.read(dataChangeNotifierProvider.notifier).state++;
                        }
                      }
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('删除'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
