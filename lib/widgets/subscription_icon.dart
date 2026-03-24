import 'package:flutter/material.dart';
import '../utils/app_icons.dart';

class SubscriptionIcon extends StatelessWidget {
  final String iconName; // URL or Material Icon Key
  final int colorValue;
  final double size;
  final double padding;

  const SubscriptionIcon({
    super.key,
    required this.iconName,
    required this.colorValue,
    this.size = 26,
    this.padding = 8,
  });

  @override
  Widget build(BuildContext context) {
    var finalIconPath = iconName;
    final fallbackIcon = AppIcons.getIcon(iconName);
    final color = Color(colorValue);

    // URLでない場合はプレセットから検索
    if (!finalIconPath.startsWith('http')) {
      for (final preset in AppIcons.presets) {
        if (preset.id.contains(finalIconPath) ||
            preset.name.toLowerCase() == finalIconPath.toLowerCase()) {
          finalIconPath = preset.id;
          break;
        }
      }
    }

    // URLであれば画像、そうでなければアイコンを表示
    if (finalIconPath.startsWith('http')) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: Image.network(
          finalIconPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: color, size: size),
        ),
      );
    }

    return Icon(fallbackIcon, color: color, size: size);
  }
}
