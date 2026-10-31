import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Themed text field with a floating label (so the label is always exposed to
/// screen readers), optional prefix icon, and built-in password reveal toggle.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofillHints,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.hideCounter = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.prefix,
    this.pill = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final TextCapitalization textCapitalization;

  /// Hides the `0/maxLength` counter while still enforcing [maxLength].
  final bool hideCounter;
  final TextAlign textAlign;
  final TextStyle? style;

  /// A custom widget at the start of the field (for example a country
  /// selector). Takes the place of [prefixIcon].
  final Widget? prefix;

  /// Fully rounded field with a soft focus glow. Used on branded auth.
  final bool pill;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  var _ownedFocus = false;

  @override
  void initState() {
    super.initState();
    _ownedFocus = widget.focusNode == null;
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (_ownedFocus) _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (widget.pill && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.obscureText;
    final colors = context.colors;
    final palette = context.palette;
    final focused = _focus.hasFocus;
    final hasError = widget.errorText != null;

    OutlineInputBorder pillBorder(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: AppRadii.borderPill,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final decoration = widget.pill
        ? InputDecoration(
            filled: true,
            fillColor: palette.surfaceMuted.withValues(alpha: 0.72),
            contentPadding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.lg + 2,
              AppSpacing.xl,
              AppSpacing.lg + 2,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            hintText: widget.hint ?? widget.label,
            helperText: widget.helper,
            helperMaxLines: 3,
            helperStyle: context.text.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
            errorText: widget.errorText,
            errorMaxLines: 3,
            counterText: widget.hideCounter ? '' : null,
            prefixIcon:
                widget.prefix ??
                (widget.prefixIcon == null
                    ? null
                    : Icon(widget.prefixIcon, size: 22)),
            prefixIconConstraints: widget.prefix == null
                ? null
                : const BoxConstraints(minHeight: 56),
            suffixIcon: isPassword
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscured ? AppIcons.visibility : AppIcons.visibilityOff,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
            border: pillBorder(palette.outlineSoft),
            enabledBorder: pillBorder(colors.primary.withValues(alpha: 0.35)),
            focusedBorder: pillBorder(
              colors.primary.withValues(alpha: 0.85),
              width: 1.6,
            ),
            errorBorder: pillBorder(colors.error),
            focusedErrorBorder: pillBorder(colors.error, width: 1.6),
            disabledBorder: pillBorder(palette.outlineSoft),
          )
        : InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            helperText: widget.helper,
            helperMaxLines: 3,
            errorText: widget.errorText,
            errorMaxLines: 3,
            counterText: widget.hideCounter ? '' : null,
            prefixIcon:
                widget.prefix ??
                (widget.prefixIcon == null
                    ? null
                    : Icon(widget.prefixIcon, size: 22)),
            prefixIconConstraints: widget.prefix == null
                ? null
                : const BoxConstraints(minHeight: 48),
            suffixIcon: isPassword
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscured ? AppIcons.visibility : AppIcons.visibilityOff,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          );

    final field = TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      maxLines: isPassword ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      textAlign: widget.textAlign,
      style: widget.style ?? context.text.bodyLarge,
      cursorColor: colors.primary,
      // Keep the field visible above the keyboard.
      scrollPadding: const EdgeInsets.all(96),
      decoration: decoration,
    );

    if (!widget.pill) return field;

    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.fast),
      curve: AppMotion.standard,
      decoration: BoxDecoration(
        borderRadius: AppRadii.borderPill,
        boxShadow: focused && !hasError
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.28),
                  blurRadius: 22,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: field,
    );
  }
}
