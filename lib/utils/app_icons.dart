import 'package:flutter/material.dart';

import 'app_constants.dart';

class ServicePreset {
  final String id;
  final String name;
  final String category;
  final int color;
  final IconData icon;

  const ServicePreset({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.icon,
  });
}

class AppIcons {
  static const List<ServicePreset> presets = [
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=netflix.com&sz=128',
      name: 'Netflix',
      category: AppConstants.categoryEntertainment,
      color: 0xFF000000,
      icon: Icons.play_circle_fill,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=youtube.com&sz=128',
      name: 'YouTube Premium',
      category: AppConstants.categoryEntertainment,
      color: 0xFFFF0000,
      icon: Icons.play_arrow,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=amazon.co.jp&sz=128',
      name: 'Amazon Prime',
      category: AppConstants.categoryEntertainment,
      color: 0xFF00A8E1,
      icon: Icons.shopping_bag,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=unext.jp&sz=128',
      name: 'U-NEXT',
      category: AppConstants.categoryEntertainment,
      color: 0xFF222222,
      icon: Icons.movie,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=abema.tv&sz=128',
      name: 'ABEMA',
      category: AppConstants.categoryEntertainment,
      color: 0xFF000000,
      icon: Icons.tv,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=hulu.jp&sz=128',
      name: 'Hulu',
      category: AppConstants.categoryEntertainment,
      color: 0xFF1CE783,
      icon: Icons.video_collection,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=dazn.com&sz=128',
      name: 'DAZN',
      category: AppConstants.categoryEntertainment,
      color: 0xFF000000,
      icon: Icons.sports_soccer,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=disneyplus.com&sz=128',
      name: 'Disney+',
      category: AppConstants.categoryEntertainment,
      color: 0xFF113CCF,
      icon: Icons.movie_filter,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=nintendo.co.jp&sz=128',
      name: 'Nintendo Switch Online',
      category: AppConstants.categoryEntertainment,
      color: 0xFFE60012,
      icon: Icons.sports_esports,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=playstation.com&sz=128',
      name: 'PS Plus',
      category: AppConstants.categoryEntertainment,
      color: 0xFF003087,
      icon: Icons.games,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=spotify.com&sz=128',
      name: 'Spotify',
      category: AppConstants.categoryEntertainment,
      color: 0xFF1DB954,
      icon: Icons.music_note,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=music.apple.com&sz=128',
      name: 'Apple Music',
      category: AppConstants.categoryEntertainment,
      color: 0xFFFF2D55,
      icon: Icons.audiotrack,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=line.me&sz=128',
      name: 'LINE MUSIC',
      category: AppConstants.categoryEntertainment,
      color: 0xFF00C300,
      icon: Icons.music_video,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=icloud.com&sz=128',
      name: 'iCloud+',
      category: AppConstants.categoryLifestyle,
      color: 0xFF5AC8FA,
      icon: Icons.cloud,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=google.com&sz=128',
      name: 'Google One',
      category: AppConstants.categoryLifestyle,
      color: 0xFF4285F4,
      icon: Icons.storage,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=chocozap.jp&sz=128',
      name: 'chocoZAP',
      category: AppConstants.categoryLifestyle,
      color: 0xFFFFF200,
      icon: Icons.fitness_center,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=moneyforward.com&sz=128',
      name: 'マネーフォワード ME',
      category: AppConstants.categoryFinance,
      color: 0xFFFF6600,
      icon: Icons.account_balance_wallet,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=cookpad.com&sz=128',
      name: 'クックパッド',
      category: AppConstants.categoryLifestyle,
      color: 0xFFFFBB00,
      icon: Icons.restaurant,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=tabelog.com&sz=128',
      name: '食べログ',
      category: AppConstants.categoryLifestyle,
      color: 0xFF882200,
      icon: Icons.star,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=amazon.co.jp&sz=128&path=kindle',
      name: 'Kindle Unlimited',
      category: AppConstants.categoryBooks,
      color: 0xFF00A8E1,
      icon: Icons.book,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=shonenjumpplus.com&sz=128',
      name: '少年ジャンプ+',
      category: AppConstants.categoryBooks,
      color: 0xFFFF0000,
      icon: Icons.auto_stories,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=openai.com&sz=128',
      name: 'ChatGPT Plus',
      category: AppConstants.categoryProductivity,
      color: 0xFF74AA9C,
      icon: Icons.auto_awesome,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=adobe.com&sz=128',
      name: 'Adobe CC',
      category: AppConstants.categoryProductivity,
      color: 0xFFFF0000,
      icon: Icons.palette,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=notion.so&sz=128',
      name: 'Notion',
      category: AppConstants.categoryProductivity,
      color: 0xFF000000,
      icon: Icons.edit_note,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=slack.com&sz=128',
      name: 'Slack',
      category: AppConstants.categoryProductivity,
      color: 0xFF4A154B,
      icon: Icons.forum,
    ),
    ServicePreset(
      id: 'https://www.google.com/s2/favicons?domain=canva.com&sz=128',
      name: 'Canva',
      category: AppConstants.categoryProductivity,
      color: 0xFF00C4CC,
      icon: Icons.design_services,
    ),
  ];

  static const Map<String, IconData> manualIcons = {
    'generic': Icons.subscriptions,
    'star': Icons.star,
    'heart': Icons.favorite,
    'home': Icons.home,
    'work': Icons.work,
    'money': Icons.attach_money,
    'wifi': Icons.wifi,
    'flash': Icons.flash_on,
    'book': Icons.book,
    'car': Icons.directions_car,
    'smartphone': Icons.smartphone,
    'shopping': Icons.shopping_cart,
  };

  static IconData getIcon(String iconName) {
    if (iconName.startsWith('http')) {
      for (final preset in presets) {
        if (preset.id == iconName) return preset.icon;
      }
      return Icons.subscriptions;
    }

    for (final preset in presets) {
      if (preset.id == iconName) return preset.icon;
    }

    return manualIcons[iconName] ?? Icons.subscriptions;
  }
}
