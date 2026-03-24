import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExchangeRateService {
  static const String _keyUsdToJpy = 'usd_to_jpy';
  static const String _keyEurToJpy = 'eur_to_jpy';
  static const String _keyGbpToJpy = 'gbp_to_jpy';
  static const String _keyLastUpdated = 'rate_last_updated';

  static const double defaultUsd = 150.0;
  static const double defaultEur = 160.0;
  static const double defaultGbp = 190.0;

  Future<Map<String, double>> getRates() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'USD': prefs.getDouble(_keyUsdToJpy) ?? defaultUsd,
      'EUR': prefs.getDouble(_keyEurToJpy) ?? defaultEur,
      'GBP': prefs.getDouble(_keyGbpToJpy) ?? defaultGbp,
    };
  }

  Future<void> saveRates(Map<String, double> rates) async {
    final prefs = await SharedPreferences.getInstance();
    if (rates.containsKey('USD')) {
      await prefs.setDouble(_keyUsdToJpy, rates['USD']!);
    }
    if (rates.containsKey('EUR')) {
      await prefs.setDouble(_keyEurToJpy, rates['EUR']!);
    }
    if (rates.containsKey('GBP')) {
      await prefs.setDouble(_keyGbpToJpy, rates['GBP']!);
    }
    await prefs.setString(_keyLastUpdated, DateTime.now().toIso8601String());
  }

  Future<String?> getLastUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastUpdated);
  }

  Future<Map<String, double>?> fetchLatestRates() async {
    try {
      final url = Uri.parse('https://open.er-api.com/v6/latest/JPY');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>;

      return {
        'USD': 1.0 / (rates['USD'] as num).toDouble(),
        'EUR': 1.0 / (rates['EUR'] as num).toDouble(),
        'GBP': 1.0 / (rates['GBP'] as num).toDouble(),
      };
    } catch (e) {
      debugPrint('為替レート取得エラー: $e');
      return null;
    }
  }
}
