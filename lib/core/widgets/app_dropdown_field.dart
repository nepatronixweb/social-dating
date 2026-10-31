import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Themed single-select field. Tapping it opens a menu of every [items] value.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.itemLabel,
    this.value,
    this.onChanged,
    this.hint,
    this.helperText,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final List<T> items;
  final String Function(T item) itemLabel;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selected = value;
    final canOpen = enabled && onChanged != null && items.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        return MenuAnchor(
          alignmentOffset: const Offset(0, 4),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(context.colors.surface),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
            ),
            minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
            maximumSize: WidgetStatePropertyAll(
              Size(constraints.maxWidth, 360),
            ),
          ),
          builder: (context, controller, _) {
            void toggle() {
              if (!canOpen) return;
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            }

            return Semantics(
              button: true,
              enabled: canOpen,
              expanded: controller.isOpen,
              label: selected == null
                  ? '$label. ${hint ?? 'Select'}'
                  : '$label. ${itemLabel(selected)}',
              excludeSemantics: true,
              onTap: canOpen ? toggle : null,
              child: InkWell(
                onTap: canOpen ? toggle : null,
                borderRadius: AppRadii.borderMd,
                child: InputDecorator(
                  isEmpty: selected == null,
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint,
                    helperText: helperText,
                    helperMaxLines: 2,
                    errorText: errorText,
                    errorMaxLines: 2,
                    suffixIcon: Icon(
                      AppIcons.expandMore,
                      size: AppSizes.iconLg,
                      color: enabled
                          ? context.palette.textMuted
                          : context.colors.outline,
                    ),
                  ),
                  child: Text(
                    selected == null ? '' : itemLabel(selected),
                    style: context.text.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          },
          menuChildren: [
            for (final item in items)
              MenuItemButton(
                onPressed: onChanged == null ? null : () => onChanged!(item),
                trailingIcon: selected == item
                    ? Icon(
                        AppIcons.check,
                        size: AppSizes.iconMd,
                        color: context.colors.primary,
                      )
                    : const SizedBox(width: AppSizes.iconMd),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(itemLabel(item), style: context.text.bodyLarge),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
