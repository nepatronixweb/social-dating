import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// "Resend code in 0:27" that becomes a "Resend code" button when the
/// cooldown ends.
///
/// [onResend] returns `true` when a new code was sent, which restarts the
/// cooldown; on `false` the button stays available so the person can retry.
/// Set [readyNow] to skip the wait (for example when the code has expired).
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    super.key,
    required this.onResend,
    this.cooldown = AppConstants.resendCooldown,
    this.readyNow = false,
  });

  final Future<bool> Function() onResend;
  final Duration cooldown;
  final bool readyNow;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  late int _remaining = widget.cooldown.inSeconds;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _remaining = widget.cooldown.inSeconds;
    if (_remaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    var sent = false;
    try {
      sent = await widget.onResend();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (sent) _startCountdown();
      }
    }
  }

  String get _clock {
    final minutes = _remaining ~/ 60;
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.readyNow || _remaining <= 0;

    if (_sending) {
      return const SizedBox(
        height: AppSpacing.minTouchTarget,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox.square(
            dimension: AppSizes.iconMd,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (ready) {
      return TextButton(onPressed: _resend, child: const Text('Resend code'));
    }

    return Semantics(
      container: true,
      label: 'You can request a new code in $_remaining seconds',
      excludeSemantics: true,
      child: SizedBox(
        height: AppSpacing.minTouchTarget,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              style: context.text.labelLarge?.copyWith(
                color: context.palette.textMuted,
              ),
              children: [
                const TextSpan(text: 'Resend code in '),
                TextSpan(
                  text: _clock,
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
