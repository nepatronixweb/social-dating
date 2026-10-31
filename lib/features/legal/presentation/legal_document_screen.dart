import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';

enum LegalDocument { terms, privacy }

/// Displays a legal document. Replace [_sections] with the reviewed documents
/// (or load them from the backend) before any release.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  String get _title => switch (document) {
    LegalDocument.terms => 'Terms of Service',
    LegalDocument.privacy => 'Privacy Policy',
  };

  List<(String, String)> get _sections => switch (document) {
    LegalDocument.terms => const [
      (
        'Using Social Dating',
        'Sample text. This section would explain who can use the service, '
            'including the requirement to be 18 or older.',
      ),
      (
        'Your account',
        'Sample text. This section would describe account responsibilities '
            'and what happens when an account is closed.',
      ),
      (
        'Respectful behaviour',
        'Sample text. This section would set out the community standards '
            'and how reports are handled.',
      ),
    ],
    LegalDocument.privacy => const [
      (
        'What we collect',
        'Sample text. This section would list the information collected, '
            'such as phone number, profile details and date of birth.',
      ),
      (
        'How it is used',
        'Sample text. This section would explain why each piece of '
            'information is used.',
      ),
      (
        'Your choices',
        'Sample text. This section would describe access, correction and '
            'deletion rights.',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: AppTopBar(title: _title),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Padding(
            padding: AppSpacing.pagePadding.copyWith(
              top: AppSpacing.md,
              bottom: AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(_title, style: context.text.displaySmall),
                ),
                for (final (heading, body) in _sections) ...[
                  AppSpacing.gapXl,
                  Semantics(
                    header: true,
                    child: Text(heading, style: context.text.titleLarge),
                  ),
                  AppSpacing.gapSm,
                  Text(body, style: context.text.bodyLarge),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
