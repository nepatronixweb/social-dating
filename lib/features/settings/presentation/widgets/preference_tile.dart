import 'package:flutter/material.dart';

import '../../../../core/widgets/menu_tile.dart';

/// Settings row with a switch. The whole row toggles so the control is a
/// single accessible item.
class PreferenceTile extends StatelessWidget {
  const PreferenceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: ExcludeSemantics(
        child: IgnorePointer(
          child: Switch(value: value, onChanged: onChanged),
        ),
      ),
    );
  }
}
