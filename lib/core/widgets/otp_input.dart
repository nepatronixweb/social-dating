import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// A grouped one-time-code input: one box per digit, driven by a single
/// invisible text field laid over them.
///
/// Why one field and not six: paste, SMS autofill (`oneTimeCode`), backspace
/// and screen readers all behave like an ordinary text field, while the boxes
/// give the polished look. The active box has a visible focus ring; errors
/// turn every box red and are also stated in text (colour is never the only
/// signal).
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.length = AppConstants.otpLength,
    this.focusNode,
    this.errorText,
    this.enabled = true,
    this.autofocus = true,
    this.onChanged,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final FocusNode? focusNode;

  /// Shown below the boxes, which also turn red.
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Called when the last digit is entered.
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'otp'));

  @override
  void dispose() {
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: 'Verification code',
          hint: '${widget.length} digits',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SizedBox(
              height: 68,
              child: Stack(
                children: [
                  ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        widget.controller,
                        _focusNode,
                      ]),
                      builder: (context, _) {
                        final text = widget.controller.text;
                        final active = text.length.clamp(0, widget.length - 1);
                        return Row(
                          children: [
                            for (var i = 0; i < widget.length; i++) ...[
                              if (i > 0) AppSpacing.gapSm,
                              Expanded(
                                child: _OtpBox(
                                  character: i < text.length ? text[i] : '',
                                  isActive:
                                      widget.enabled &&
                                      _focusNode.hasFocus &&
                                      i == active,
                                  hasError: hasError,
                                  enabled: widget.enabled,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      autofocus: widget.autofocus,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(widget.length),
                      ],
                      // The boxes draw the digits; this field only captures
                      // input, so everything it paints is transparent.
                      showCursor: false,
                      enableInteractiveSelection: false,
                      style: const TextStyle(color: Colors.transparent),
                      cursorColor: Colors.transparent,
                      decoration: const InputDecoration(
                        filled: false,
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        counterText: '',
                      ),
                      onChanged: _handleChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.resolve(context, AppMotion.fast),
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppIcons.error,
                          size: AppSizes.iconMd,
                          color: context.colors.error,
                        ),
                        AppSpacing.gapSm,
                        Expanded(
                          child: Text(
                            widget.errorText!,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.character,
    required this.isActive,
    required this.hasError,
    required this.enabled,
  });

  final String character;
  final bool isActive;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final Color borderColor;
    final double borderWidth;
    if (hasError) {
      borderColor = colors.error;
      borderWidth = 2;
    } else if (isActive) {
      borderColor = colors.primary;
      borderWidth = 2;
    } else {
      borderColor = colors.primary.withValues(alpha: 0.32);
      borderWidth = 1.4;
    }

    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.fast),
      curve: AppMotion.standard,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled
            ? palette.surfaceMuted.withValues(alpha: 0.65)
            : palette.surfaceMuted,
        borderRadius: AppRadii.borderLg,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isActive && !hasError
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.32),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (character.isEmpty && !isActive)
            SizedBox(
              width: AppSpacing.md,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.textMuted.withValues(alpha: 0.7),
                  borderRadius: AppRadii.borderPill,
                ),
              ),
            )
          else if (character.isNotEmpty)
            Text(
              character,
              style: context.text.headlineMedium?.copyWith(
                color: enabled ? colors.onSurface : palette.textMuted,
              ),
            ),
          if (isActive && enabled)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: SizedBox(
                width: 2,
                height: AppSizes.iconLg,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: AppRadii.borderPill,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
