import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/subscription.dart';
import '../utils/app_colors.dart';
import '../utils/app_icons.dart';
import 'subscription_icon.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final Map<String, double>? rates;
  final VoidCallback? onTap;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.rates,
    this.onTap,
  });

  String _formatCurrency(double value, String currency) {
    if (currency == 'JPY') {
      return NumberFormat('#,###').format(value.round());
    }
    return NumberFormat('#,##0.00').format(value);
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '¥';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = subscription.computedStatus;
    final isInactive = status == 'cancelled' || status == 'expired';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = DateTime(
      subscription.deadlineDate.year,
      subscription.deadlineDate.month,
      subscription.deadlineDate.day,
    );
    final diffDays = deadline.difference(today).inDays;

    final serviceColor = Color(subscription.iconColorValue);
    final symbol = _getCurrencySymbol(subscription.currency);

    double? priceInJPY;
    if (subscription.currency != 'JPY' && rates != null) {
      final rate = rates![subscription.currency] ?? 1.0;
      priceInJPY = subscription.averageMonthlyPrice * rate;
    }

    var statusColor = AppColors.textSub(context);
    if (subscription.progress > 0.8) {
      statusColor = const Color(0xFFFFB74D);
    }
    if (diffDays <= 0 && status == 'active') {
      statusColor = const Color(0xFFEF5350);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isInactive
                      ? AppColors.card(context)
                      : Color.alphaBlend(
                          statusColor.withValues(alpha: 0.08), // 緊急度に応じた微かな色付け
                          AppColors.card(context),
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isInactive
                        ? Colors.grey.withValues(alpha: 0.1)
                        : statusColor.withValues(alpha: 0.3), // 境界線も少し強調
                    width: 1.2, // 少し太くして存在感を出す
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isInactive ? Colors.transparent : statusColor).withValues(alpha: 0.06),
                      offset: const Offset(0, 4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 左端のカテゴリカラーバー
                      Container(
                        width: 10,
                        color: AppColors.getCategoryColor(subscription.category),
                      ),
                      const SizedBox(width: 12),
                      // メインコンテンツ
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 16, 12, 16),
                          child: Row(
                            children: [
                              // アイコン
                              Container(
                                width: 50,
                                height: 50,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: serviceColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: SubscriptionIcon(
                                  iconName: subscription.iconName,
                                  colorValue: subscription.iconColorValue,
                                  size: 26,
                                  padding: 8,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // 名前と支払い方法
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      subscription.name,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMain(context),
                                        decoration: isInactive ? TextDecoration.lineThrough : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${subscription.paymentMethod.isNotEmpty ? "${subscription.paymentMethod} • " : ""}${subscription.cycle == 'yearly' ? '年額' : '月額'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSub(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 金額と締切
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        symbol,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textMain(context),
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(
                                          subscription.averageMonthlyPrice,
                                          subscription.currency,
                                        ),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textMain(context),
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isInactive)
                                    Text(
                                      diffDays < 0 ? '締切超過' : diffDays == 0 ? '今日が締切' : 'あと $diffDays 日',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    )
                                  else
                                    Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 右端の矢印
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.textSub(context).withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // トライアルバッジ (右上に固定) - スカイブルー
          if (subscription.billingType == 'trial_days' && !isInactive)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF29B6F6), // スカイブルー
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'FREE TRIAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
