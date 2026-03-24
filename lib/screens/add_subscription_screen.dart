import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/subscription.dart';
import '../utils/app_colors.dart';
import '../widgets/subscription_icon.dart';
import 'categories_screen.dart';
import 'payment_methods_screen.dart';
import 'service_preset_picker_screen.dart';
import '../utils/app_icons.dart';

class AddSubscriptionScreen extends StatefulWidget {
  final Subscription? existingSubscription;

  const AddSubscriptionScreen({super.key, this.existingSubscription});

  @override
  State<AddSubscriptionScreen> createState() => AddSubscriptionScreenState();
}

class AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  double _price = 0.0;
  String _currency = 'JPY';
  String _cycle = 'monthly';
  DateTime _nextBillingDate = DateTime.now();
  String _cancellationRule = 'typeA';
  int _offsetDays = 0;
  String _memo = '';
  String _category = '未分類';
  List<String> _categories = [];

  String _iconName = 'generic';
  int _iconColorValue = 0xFF4C6FFF;

  String _billingType = 'relative';
  int _trialDays = 31;
  DateTime _startDate = DateTime.now();

  String _selectedPaymentMethod = '';
  List<String> _paymentMethodHistory = [];

  List<int> _notificationDays = [1];
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);

  bool get isEditMode => widget.existingSubscription != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _loadPaymentMethods();
    _loadCategories();

    final sub = widget.existingSubscription;
    if (sub != null) {
      _nameController.text = sub.name;
      _price = sub.price;
      _currency = sub.currency;
      _cycle = sub.cycle;
      _nextBillingDate = sub.nextBillingDate;
      _cancellationRule = sub.cancellationRule;
      _offsetDays = sub.offsetDays;
      _category = sub.category;
      _memo = sub.memo;
      _selectedPaymentMethod = sub.paymentMethod;
      _iconName = sub.iconName;
      _iconColorValue = sub.iconColorValue;
      _billingType = sub.billingType;
      _trialDays = sub.trialDays;
      _startDate = sub.startDate ?? DateTime.now();
      _notificationDays = List<int>.from(sub.notificationDays);
      _notificationTime = sub.notificationTime;
    } else {
      _updateCalculatedDate();
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentMethods() async {
    final list = await DatabaseHelper.instance.readAllPaymentMethods();
    if (!mounted) return;
    setState(() {
      _paymentMethodHistory = list;
    });
  }

  Future<void> _loadCategories() async {
    final list = await DatabaseHelper.instance.readAllCategories();
    if (!mounted) return;
    setState(() {
      _categories = list;
      if (!_categories.contains(_category)) {
        _category = '未分類';
      }
    });
  }

  String? _suggestedServiceName;

  void _onNameChanged() {
    final text = _nameController.text.trim().toLowerCase();
    final domainRegExp = RegExp(r'^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$');
    
    // ドメイン形式でない場合は提案を消すだけにする（アイコンは保持する）
    if (!domainRegExp.hasMatch(text)) {
      if (_suggestedServiceName != null) {
        setState(() => _suggestedServiceName = null);
      }
      return;
    }

    final logoUrl = 'https://www.google.com/s2/favicons?domain=$text&sz=128';
    
    setState(() {
      // ドメインが入力された時のみ、アイコンを自動更新する（自動取得モード）
      // ユーザーが一度手動でプリセット等を選んでいる場合は上書きしない等の考慮も可能だが、
      // 基本はドメイン入力があればそれを優先して表示する。
      if (_iconName != logoUrl) {
        _iconName = logoUrl;
      }
      
      // 候補名の生成
      final parts = text.split('.');
      if (parts.isNotEmpty) {
        String serviceName = parts[0];
        if (serviceName.isNotEmpty) {
          final suggestion = serviceName[0].toUpperCase() + serviceName.substring(1);
          // 現在の入力内容と異なる場合のみ提案を表示
          if (suggestion != _nameController.text.trim()) {
            _suggestedServiceName = suggestion;
          } else {
            _suggestedServiceName = null;
          }
        }
      }
    });
  }

  void _applySuggestion() {
    if (_suggestedServiceName == null) return;
    setState(() {
      _nameController.text = _suggestedServiceName!;
      _suggestedServiceName = null;
      // カーソルを末尾に移動
      _nameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _nameController.text.length)
      );
    });
  }

  void _updateCalculatedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime computedDate = today;

    if (_billingType == 'relative') {
      computedDate = today.add(const Duration(days: 30));
    } else if (_billingType == 'calendar_monthly') {
      computedDate = today.month == 12
          ? DateTime(today.year + 1, 1, 1)
          : DateTime(today.year, today.month + 1, 1);
    } else if (_billingType == 'trial_days') {
      computedDate = _startDate.add(Duration(days: _trialDays));
    } else if (_billingType == 'custom') {
      computedDate = _nextBillingDate;
    }

    if (!mounted) return;
    setState(() {
      _nextBillingDate = computedDate;
    });
  }

  Future<void> _selectCustomDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _nextBillingDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) => _buildThemePicker(context, child),
    );
    if (pickedDate == null) return;

    setState(() {
      _nextBillingDate = pickedDate;
      _billingType = 'custom';
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => _buildThemePicker(context, child),
    );
    if (pickedDate == null) return;

    setState(() {
      _startDate = pickedDate;
      _updateCalculatedDate();
    });
  }

  Widget _buildThemePicker(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.card(context),
          onSurface: AppColors.textMain(context),
        ),
      ),
      child: child!,
    );
  }

  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      _formKey.currentState!.save();
      final notifyTypeJson = Subscription.createNotifyTypeJson(
        _notificationDays,
        _notificationTime,
      );

      final sub = Subscription(
        id: widget.existingSubscription?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        price: _price,
        currency: _currency,
        cycle: _cycle,
        nextBillingDate: _nextBillingDate,
        cancellationRule: _cancellationRule,
        offsetDays: _cancellationRule == 'typeC' ? _offsetDays : 0,
        category: _category,
        notifyType: notifyTypeJson,
        paymentMethod: _selectedPaymentMethod,
        iconName: _iconName,
        iconColorValue: _iconColorValue,
        billingType: _billingType,
        trialDays: _trialDays,
        startDate: _startDate,
        memo: _memo,
        isCancelled: widget.existingSubscription?.isCancelled ?? false,
      );

      if (isEditMode) {
        await DatabaseHelper.instance.updateSubscription(sub);
      } else {
        await DatabaseHelper.instance.insertSubscription(sub);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: $e'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _onSelectPreset(ServicePreset preset) {
    setState(() {
      _nameController.text = preset.name;
      _category = preset.category;
      _iconName = preset.id;
      _iconColorValue = preset.color;
    });
  }

  Future<void> _pickPreset() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServicePresetPickerScreen()),
    );
    if (result is ServicePreset) {
      _onSelectPreset(result);
    }
  }

  Future<void> _selectNotificationTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) => _buildThemePicker(context, child),
    );
    if (picked != null) {
      setState(() => _notificationTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryOptions =
        _categories.isEmpty ? <String>['未分類'] : List<String>.from(_categories);
    if (!categoryOptions.contains(_category)) {
      categoryOptions.insert(0, _category);
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(isEditMode ? 'サブスクの編集' : 'サブスクの追加'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('基本設定 (必須)', context),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration(
                        'サービス名',
                        context,
                        hintText: '例: Netflix',
                      ).copyWith(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Container(
                            width: 36,
                            height: 36,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Color(_iconColorValue).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SubscriptionIcon(
                              iconName: _iconName,
                              colorValue: _iconColorValue,
                              size: 24,
                              padding: 4,
                            ),
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.apps_outlined),
                          onPressed: _pickPreset,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'サービス名を入力してください';
                        }
                        return null;
                      },
                    ),
                    if (_suggestedServiceName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: _applySuggestion,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_fix_high, size: 14, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  '"$_suggestedServiceName" に変換',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 88,
                          child: DropdownButtonFormField<String>(
                            initialValue: _currency,
                            decoration: _buildInputDecoration('', context),
                            items: const [
                              DropdownMenuItem(value: 'JPY', child: Text('¥')),
                              DropdownMenuItem(value: 'USD', child: Text(r'$')),
                              DropdownMenuItem(value: 'EUR', child: Text('€')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _currency = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: _price == 0 ? '' : _price.toString(),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _buildInputDecoration('金額', context),
                            validator: (v) {
                              if (v == null ||
                                  v.trim().isEmpty ||
                                  double.tryParse(v) == null) {
                                return '金額を入力してください';
                              }
                              return null;
                            },
                            onSaved: (v) => _price = double.parse(v!.trim()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _cycle,
                            decoration: _buildInputDecoration('単位', context),
                            items: const [
                              DropdownMenuItem(value: 'monthly', child: Text('月')),
                              DropdownMenuItem(value: 'yearly', child: Text('年')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _cycle = v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.withValues(alpha: 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('支払い時期と更新期限', context),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _billingType,
                      decoration: _buildInputDecoration('請求基準', context),
                      items: const [
                        DropdownMenuItem(
                          value: 'relative',
                          child: Text('登録日から1か月'),
                        ),
                        DropdownMenuItem(
                          value: 'calendar_monthly',
                          child: Text('毎月1日'),
                        ),
                        DropdownMenuItem(
                          value: 'trial_days',
                          child: Text('トライアル日数'),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('カスタム日付'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _billingType = v);
                        _updateCalculatedDate();
                      },
                    ),
                    if (_billingType == 'trial_days') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _trialDays.toString(),
                              keyboardType: TextInputType.number,
                              decoration: _buildInputDecoration(
                                'トライアル期間 (日)',
                                context,
                              ),
                              onChanged: (v) {
                                _trialDays = int.tryParse(v) ?? 31;
                                _updateCalculatedDate();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _selectStartDate(context),
                            icon: const Icon(Icons.event),
                            label: Text(DateFormat('MM/dd').format(_startDate)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _selectCustomDate(context),
                      child: InputDecorator(
                        decoration: _buildInputDecoration('次回支払日', context),
                        child: Text(
                          DateFormat('yyyy/MM/dd').format(_nextBillingDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _cancellationRule,
                      decoration: _buildInputDecoration('解約期限', context),
                      items: const [
                        DropdownMenuItem(
                          value: 'typeA',
                          child: Text('前日まで'),
                        ),
                        DropdownMenuItem(
                          value: 'typeB',
                          child: Text('当日まで'),
                        ),
                        DropdownMenuItem(
                          value: 'typeC',
                          child: Text('X日前まで'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _cancellationRule = v);
                      },
                    ),
                    if (_cancellationRule == 'typeC') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _offsetDays.toString(),
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration('解約期限 (日前)', context),
                        validator: (v) {
                          if (v == null || int.tryParse(v) == null) {
                            return '日数を入力してください';
                          }
                          return null;
                        },
                        onSaved: (v) => _offsetDays = int.parse(v!),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('通知設定 (任意)', context),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [0, 1, 3, 7, 14].map((days) {
                        final isSelected = _notificationDays.contains(days);
                        return FilterChip(
                          label: Text(days == 0 ? '当日' : '$days日前'),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _notificationDays.add(days);
                              } else {
                                _notificationDays.remove(days);
                              }
                            });
                          },
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primary,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _selectNotificationTime(context),
                      child: InputDecorator(
                        decoration: _buildInputDecoration('通知時刻', context),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              '${_notificationTime.hour.toString().padLeft(2, '0')}:${_notificationTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('詳細設定 (任意)', context),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: _buildInputDecoration('カテゴリ', context),
                            items: categoryOptions
                                .map(
                                  (cat) => DropdownMenuItem<String>(
                                    value: cat,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: AppColors.getCategoryColor(cat),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(cat),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _category = v);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.settings_outlined,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CategoriesScreen(),
                              ),
                            );
                            _loadCategories();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedPaymentMethod.isEmpty
                                ? null
                                : _selectedPaymentMethod,
                            decoration: _buildInputDecoration('支払い方法', context),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('選択なし'),
                              ),
                              ..._paymentMethodHistory.map(
                                (m) => DropdownMenuItem<String?>(
                                  value: m,
                                  child: Text(m),
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedPaymentMethod = v ?? '');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: '支払い方法を管理',
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PaymentMethodsScreen(),
                              ),
                            );
                            _loadPaymentMethods();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _memo,
                      maxLines: 2,
                      decoration: _buildInputDecoration('メモ', context),
                      onSaved: (v) => _memo = v ?? '',
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveSubscription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isEditMode ? '更新する' : 'このサブスクを追加する',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w900,
        fontSize: 13,
        letterSpacing: 1.2,
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    BuildContext context, {
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      fillColor: AppColors.card(context),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(fontSize: 14),
    );
  }
}
