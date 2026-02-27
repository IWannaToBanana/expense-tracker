import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/category.dart';
import '../../../models/transaction.dart';
import '../../../providers/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../services/storage_service.dart';
import '../../../services/ocr_service.dart';
import '../../widgets/category_picker.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final double? initialAmount;
  final Transaction? transaction; // 添加 transaction 参数用于编辑

  const AddTransactionPage({
    super.key,
    this.initialAmount,
    this.transaction,
  });

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final OCRService _ocrService;

  TransactionType _selectedType = TransactionType.expense;
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  Transaction? _editingTransaction; // 正在编辑的交易
  bool _isRecognizing = false;

  @override
  void initState() {
    super.initState();
    _ocrService = OCRService();

    // 如果是编辑模式，预填数据
    if (widget.transaction != null) {
      _editingTransaction = widget.transaction;
      _selectedType = widget.transaction!.type;
      _selectedCategory = Category(
        id: widget.transaction!.categoryId,
        name: widget.transaction!.categoryName,
        icon: widget.transaction!.categoryIcon,
        color: widget.transaction!.categoryColor,
        type: widget.transaction!.type,
      );
      _amountController.text = widget.transaction!.amount.toStringAsFixed(2);
      _noteController.text = widget.transaction!.note ?? '';
      _selectedDate = widget.transaction!.date;
    } else if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 默认选中第一个分类
    if (_selectedCategory == null) {
      final categories = Category.getCategoriesByType(_selectedType);
      if (categories.isNotEmpty) {
        _selectedCategory = categories.first;
      }
    }

    final isEditMode = _editingTransaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? '编辑账目' : '记一笔'),
        actions: [
          TextButton(
            onPressed: _saveTransaction,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 支出/收入切换
            _buildTypeToggle(),

            const SizedBox(height: 24),

            // 金额输入
            _buildAmountInput(),

            const SizedBox(height: 24),

            // 分类选择
            _buildCategorySection(),

            const SizedBox(height: 24),

            // 日期选择
            _buildDateSection(),

            const SizedBox(height: 24),

            // 备注输入
            _buildNoteSection(),

            const SizedBox(height: 32),

            // 保存按钮
            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedType == TransactionType.expense
                    ? AppColors.expense
                    : AppColors.income,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isEditMode ? '保存修改' : '保存${_selectedType.displayName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
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
              onTap: () {
                setState(() {
                  _selectedType = TransactionType.expense;
                  _selectedCategory = Category.expenseCategories.first;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedType == TransactionType.expense
                      ? AppColors.expense
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '支出',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedType == TransactionType.expense
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedType = TransactionType.income;
                  _selectedCategory = Category.incomeCategories.first;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedType == TransactionType.income
                      ? AppColors.income
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '收入',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedType == TransactionType.income
                        ? Colors.white
                        : AppColors.textSecondary,
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

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '金额',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            // OCR 识别按钮
            if (!_isRecognizing)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _isRecognizing ? null : _captureAndRecognize,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('拍照识别'),
                    style: TextButton.styleFrom(
                      foregroundColor: _selectedType == TransactionType.expense
                          ? AppColors.expense
                          : AppColors.income,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isRecognizing ? null : _pickAndRecognize,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('相册识别'),
                    style: TextButton.styleFrom(
                      foregroundColor: _selectedType == TransactionType.expense
                          ? AppColors.expense
                          : AppColors.income,
                    ),
                  ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color!,
            ),
          ),
          child: Row(
            children: [
              Text(
                '¥',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 32,
                      color: _selectedType == TransactionType.expense
                          ? AppColors.expense
                          : AppColors.income,
                    ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontSize: 28,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: 32,
                      ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入金额';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return '请输入有效金额';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    final categories = Category.getCategoriesByType(_selectedType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分类',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        CategoryPicker(
          categories: categories,
          selectedCategory: _selectedCategory,
          onCategorySelected: (category) {
            setState(() {
              _selectedCategory = category;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Text(
              _formatDate(_selectedDate),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '备注（可选）',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color!,
            ),
          ),
          child: TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '添加备注...',
            ),
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(date.year, date.month, date.day);

    if (selectedDay == today) {
      return '今天';
    } else if (selectedDay == today.subtract(const Duration(days: 1))) {
      return '昨天';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  /// 从相册选择图片并识别金额
  Future<void> _pickAndRecognize() async {
    setState(() {
      _isRecognizing = true;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        // 显示识别中的提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('正在识别金额...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
        }

        final amount = await _ocrService.recognizeAmount(image.path);

        if (mounted) {
          // 关闭loading提示
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (amount != null) {
            _amountController.text = amount.toStringAsFixed(2);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('识别到金额: ¥${amount.toStringAsFixed(2)}'),
                backgroundColor: AppColors.income,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('未能识别到金额，请手动输入'),
                backgroundColor: AppColors.expense,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('识别失败: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizing = false;
        });
      }
    }
  }

  /// 拍照并识别金额
  Future<void> _captureAndRecognize() async {
    setState(() {
      _isRecognizing = true;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        // 显示识别中的提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('正在识别金额...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
        }

        final amount = await _ocrService.recognizeAmount(image.path);

        if (mounted) {
          // 关闭loading提示
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          if (amount != null) {
            _amountController.text = amount.toStringAsFixed(2);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('识别到金额: ¥${amount.toStringAsFixed(2)}'),
                backgroundColor: AppColors.income,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('未能识别到金额，请手动输入'),
                backgroundColor: AppColors.expense,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('识别失败: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizing = false;
        });
      }
    }
  }

  void _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    final amount = double.parse(_amountController.text);
    final storageService = ref.read(storageServiceProvider);

    if (_editingTransaction != null) {
      // 更新现有交易
      _editingTransaction!.amount = amount;
      _editingTransaction!.type = _selectedType;
      _editingTransaction!.categoryId = _selectedCategory!.id;
      _editingTransaction!.categoryName = _selectedCategory!.name;
      _editingTransaction!.categoryIcon = _selectedCategory!.icon;
      _editingTransaction!.categoryColor = _selectedCategory!.color;
      _editingTransaction!.note = _noteController.text.isEmpty ? null : _noteController.text;
      _editingTransaction!.date = _selectedDate;

      await storageService.updateTransaction(_editingTransaction!);

      if (mounted) {
        Navigator.pop(context);
        ref.read(dataChangeNotifierProvider.notifier).state++;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已更新账目'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } else {
      // 创建新交易
      final transaction = Transaction.create(
        amount: amount,
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        categoryIcon: _selectedCategory!.icon,
        categoryColor: _selectedCategory!.color,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        date: _selectedDate,
        type: _selectedType,
      );

      await storageService.addTransaction(transaction);

      if (mounted) {
        Navigator.pop(context);
        ref.read(dataChangeNotifierProvider.notifier).state++;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加${_selectedType.displayName} ¥${amount.toStringAsFixed(2)}'),
            backgroundColor: _selectedType == TransactionType.expense
                ? AppColors.expense
                : AppColors.income,
          ),
        );
      }
    }
  }
}
