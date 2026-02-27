import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../../../models/transaction.dart';
import '../../../models/category.dart';
import '../../../providers/providers.dart';
import '../../../services/storage_service.dart';

class ChartsPage extends ConsumerStatefulWidget {
  const ChartsPage({super.key});

  @override
  ConsumerState<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends ConsumerState<ChartsPage> {
  bool _showExpense = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final storageService = ref.watch(storageServiceProvider);
    final _ = ref.watch(dataChangeNotifierProvider); // 监听数据变化

    // 获取选中月份的数据
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final transactions = storageService.getTransactionsInRange(monthStart, monthEnd);
    final filteredTransactions = transactions.where((t) => t.type == (_showExpense ? TransactionType.expense : TransactionType.income)).toList();

    // 按分类汇总
    final categoryData = _groupByCategory(filteredTransactions);
    final totalAmount = categoryData.fold(0.0, (sum, item) => sum + item['amount'] as double);

    return SafeArea(
      child: Column(
        children: [
          // 顶部切换栏
          _buildHeader(),

          // 月份选择器
          _buildMonthSelector(),

          // 支出/收入切换
          _buildTypeToggle(),

          // 饼图或空状态
          categoryData.isEmpty ? _buildEmptyState() : _buildPieChart(categoryData, totalAmount),

          // 分类列表
          Expanded(
            child: categoryData.isEmpty
                ? _buildEmptyListState()
                : _buildCategoryList(categoryData, totalAmount),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupByCategory(List<Transaction> transactions) {
    final Map<String, Map<String, dynamic>> categoryMap = {};

    for (var transaction in transactions) {
      if (!categoryMap.containsKey(transaction.categoryId)) {
        final category = Category.getCategoryById(transaction.categoryId);
        categoryMap[transaction.categoryId] = {
          'name': transaction.categoryName,
          'icon': transaction.categoryIcon,
          'color': _colorFromHex(transaction.categoryColor),
          'amount': 0.0,
        };
      }
      categoryMap[transaction.categoryId]!['amount'] =
          (categoryMap[transaction.categoryId]!['amount'] as double) + transaction.amount;
    }

    // 转换为列表并按金额排序
    final list = categoryMap.values.toList();
    list.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    return list;
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
            '统计图表',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              // TODO: 选择月份
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
              });
            },
          ),
          Text(
            DateFormat('yyyy年MM月').format(_selectedMonth),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final now = DateTime.now();
              final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
              if (nextMonth.isBefore(now) || nextMonth.month == now.month && nextMonth.year == now.year) {
                setState(() {
                  _selectedMonth = nextMonth;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showExpense = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _showExpense ? AppColors.expense : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '支出',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _showExpense ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showExpense = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_showExpense ? AppColors.income : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '收入',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_showExpense ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<Map<String, dynamic>> categoryData, double totalAmount) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 70,
              borderData: FlBorderData(show: false),
              sections: categoryData.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final amount = item['amount'] as double;
                final color = item['color'] as Color;
                final percentage = totalAmount > 0 ? (amount / totalAmount * 100) : 0.0;

                return PieChartSectionData(
                  value: amount,
                  title: '${percentage.toStringAsFixed(1)}%',
                  color: color,
                  radius: 16,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
          // 中心总计
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _showExpense ? '总支出' : '总收入',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '¥${totalAmount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 24,
                      color: _showExpense ? AppColors.expense : AppColors.income,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<Map<String, dynamic>> categoryData, double totalAmount) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categoryData.length,
      itemBuilder: (context, index) {
        final item = categoryData[index];
        final amount = item['amount'] as double;
        final color = item['color'] as Color;
        final percentage = totalAmount > 0 ? (amount / totalAmount * 100) : 0.0;

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
              // 图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    item['icon'] as String,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 分类名称
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] as String,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: color,
                          ),
                    ),
                  ],
                ),
              ),

              // 进度条
              SizedBox(
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 金额
              Text(
                '¥${amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              '暂无${_showExpense ? "支出" : "收入"}记录',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyListState() {
    return Center(
      child: Text(
        '暂无${_showExpense ? "支出" : "收入"}分类数据',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }

  Color _colorFromHex(String hexColor) {
    final hex = hexColor.replaceAll('#', '').substring(2);
    return Color(int.parse('FF$hex', radix: 16));
  }
}
