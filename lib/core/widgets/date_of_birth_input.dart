import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/age.dart';
import '../utils/theme_context.dart';
import 'app_text_field.dart';

/// Day / month / year entry. Typed (not a calendar picker) because picking a
/// birth year by scrolling back decades is slow and frustrating; digits are
/// quick on a numeric keypad. Focus moves on automatically when a part is full.
///
/// Reports a [BirthDateParse] on every change. Messages for impossible dates
/// are shown here; *eligibility* feedback (under 18) is up to the screen,
/// which has more room to explain it.
class DateOfBirthInput extends StatefulWidget {
  const DateOfBirthInput({
    super.key,
    required this.today,
    required this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
  });

  /// The current date, injected so behaviour is testable.
  final DateTime today;
  final ValueChanged<BirthDateParse> onChanged;

  /// Called when the keyboard "done" action is pressed on the year field.
  final VoidCallback? onSubmitted;
  final bool enabled;
  final bool autofocus;

  @override
  State<DateOfBirthInput> createState() => _DateOfBirthInputState();
}

class _DateOfBirthInputState extends State<DateOfBirthInput> {
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  final _dayFocus = FocusNode(debugLabel: 'dob-day');
  final _monthFocus = FocusNode(debugLabel: 'dob-month');
  final _yearFocus = FocusNode(debugLabel: 'dob-year');

  BirthDateParse _parse = const BirthDateParse.invalid(
    BirthDateIssue.incomplete,
  );

  @override
  void dispose() {
    for (final c in [_day, _month, _year]) {
      c.dispose();
    }
    for (final f in [_dayFocus, _monthFocus, _yearFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _update({FocusNode? advanceTo, bool advance = false}) {
    final parse = BirthDateParser.parse(
      day: _day.text,
      month: _month.text,
      year: _year.text,
      today: widget.today,
    );
    setState(() => _parse = parse);
    widget.onChanged(parse);
    if (advance) advanceTo?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final message = _parse.message;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: 'Date of birth',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _part(
                  label: 'Day',
                  hint: 'DD',
                  controller: _day,
                  focusNode: _dayFocus,
                  length: 2,
                  autofocus: widget.autofocus,
                  next: _monthFocus,
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                flex: 2,
                child: _part(
                  label: 'Month',
                  hint: 'MM',
                  controller: _month,
                  focusNode: _monthFocus,
                  length: 2,
                  next: _yearFocus,
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                flex: 3,
                child: _part(
                  label: 'Year',
                  hint: 'YYYY',
                  controller: _year,
                  focusNode: _yearFocus,
                  length: 4,
                  last: true,
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: AppMotion.resolve(context, AppMotion.fast),
          alignment: Alignment.topLeft,
          child: message == null
              ? const SizedBox(width: double.infinity)
              : Padding(
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
                            message,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _part({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required int length,
    FocusNode? next,
    bool last = false,
    bool autofocus = false,
  }) {
    return AppTextField(
      label: label,
      hint: hint,
      controller: controller,
      focusNode: focusNode,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      textAlign: TextAlign.center,
      maxLength: length,
      hideCounter: true,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) =>
          _update(advance: value.length == length, advanceTo: next),
      onSubmitted: last ? (_) => widget.onSubmitted?.call() : null,
    );
  }
}
