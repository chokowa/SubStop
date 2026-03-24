import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/exchange_rate_service.dart';
import '../utils/app_colors.dart';

class ExchangeRateSettingsScreen extends StatefulWidget {
  const ExchangeRateSettingsScreen({super.key});

  @override
  State<ExchangeRateSettingsScreen> createState() =>
      _ExchangeRateSettingsScreenState();
}

class _ExchangeRateSettingsScreenState extends State<ExchangeRateSettingsScreen> {
  final _service = ExchangeRateService();
  final _usdController = TextEditingController();
  final _eurController = TextEditingController();
  final _gbpController = TextEditingController();

  bool _isLoading = false;
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void dispose() {
    _usdController.dispose();
    _eurController.dispose();
    _gbpController.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    final rates = await _service.getRates();
    final lastUpdatedString = await _service.getLastUpdated();

    if (!mounted) return;

    setState(() {
      _usdController.text = rates['USD']!.toStringAsFixed(2);
      _eurController.text = rates['EUR']!.toStringAsFixed(2);
      _gbpController.text = rates['GBP']!.toStringAsFixed(2);
      if (lastUpdatedString != null) {
        final dt = DateTime.parse(lastUpdatedString);
        _lastUpdated = DateFormat('yyyy/MM/dd HH:mm').format(dt);
      }
    });
  }

  Future<void> _fetchAndApplyRates() async {
    setState(() => _isLoading = true);
    final latest = await _service.fetchLatestRates();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (latest != null) {
      setState(() {
        _usdController.text = latest['USD']!.toStringAsFixed(2);
        _eurController.text = latest['EUR']!.toStringAsFixed(2);
        _gbpController.text = latest['GBP']!.toStringAsFixed(2);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('最新レートを反映しました。保存すると確定されます。'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('レート取得に失敗しました。ネットワークを確認してください。'),
        ),
      );
    }
  }

  Future<void> _save() async {
    final usd =
        double.tryParse(_usdController.text) ?? ExchangeRateService.defaultUsd;
    final eur =
        double.tryParse(_eurController.text) ?? ExchangeRateService.defaultEur;
    final gbp =
        double.tryParse(_gbpController.text) ?? ExchangeRateService.defaultGbp;

    await _service.saveRates({'USD': usd, 'EUR': eur, 'GBP': gbp});
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text(
          '為替・レート設定',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textMain(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '為替レート (1通貨あたりの円換算)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            _buildRateInput('USD (米ドル)', _usdController, Icons.attach_money),
            const SizedBox(height: 16),
            _buildRateInput('EUR (ユーロ)', _eurController, Icons.euro),
            const SizedBox(height: 16),
            _buildRateInput('GBP (英ポンド)', _gbpController, Icons.currency_pound),
            const SizedBox(height: 32),
            Center(
              child: TextButton.icon(
                onPressed: _isLoading ? null : _fetchAndApplyRates,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(_isLoading ? '取得中...' : 'オンラインで最新レートを取得'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_lastUpdated != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '最終更新: $_lastUpdated',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '設定を保存',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'この画面で保存したレートは、ダッシュボードや分析画面の円換算に使用されます。',
              style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateInput(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textMain(context),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            suffixText: 'JPY',
            filled: true,
            fillColor: AppColors.card(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
