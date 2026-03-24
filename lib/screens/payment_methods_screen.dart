import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/app_colors.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  PaymentMethodsScreenState createState() => PaymentMethodsScreenState();
}

class PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<String> _methods = [];
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    final list = await DatabaseHelper.instance.readAllPaymentMethods();
    setState(() {
      _methods = list;
    });
  }

  Future<void> _addMethod() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    // ボタン押下時にキーボードを確実に閉じる
    FocusScope.of(context).unfocus();

    try {
      await DatabaseHelper.instance.insertPaymentMethod(name);
      _controller.clear();
      await _loadMethods();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$name」を追加しました'),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登録に失敗しました: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _deleteMethod(String name) async {
    await DatabaseHelper.instance.deletePaymentMethod(name);
    _loadMethods();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$name」を削除しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('支払い方法の管理'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: AppColors.textMain(context), fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '例: 楽天カード, PayPay...',
                      hintStyle: TextStyle(color: AppColors.textSub(context).withOpacity(0.5)),
                      fillColor: AppColors.card(context),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addMethod,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                  child: const Text('追加'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _methods.length,
              itemBuilder: (context, index) {
                final method = _methods[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(method, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _deleteMethod(method),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'ここで登録した項目は、サブスク追加時に選択肢として表示されます。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
