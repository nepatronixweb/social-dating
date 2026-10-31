/// Message pricing and word-counting rules, as the UI presents them.
///
/// MOCK BEHAVIOUR: these numbers describe what the client displays and what the
/// in-memory mock repository enforces. They are NOT a real charge, transfer or
/// payout. A server must own word counting, who pays, balances and allocation,
/// and must reject anything the client lets through. Change values here only.
abstract final class MessageRules {
  /// Price per eligible word sent by a male account, in paisa (NPR 0.10).
  static const int paisaPerEligibleWord = 10;

  /// Loyalty points per Nepalese rupee. 100 points = NPR 1.00 = 100 paisa,
  /// so one point equals one paisa in this mock.
  static const int pointsPerNpr = 100;

  /// Proposed share of a paid word fee shown as going to the recipient.
  /// Explanatory mock copy only — never treated as a real transfer.
  static const int recipientSharePercent = 80;

  /// Proposed share of a paid word fee shown as going to the platform.
  static const int platformSharePercent = 20;

  /// Soft cap on characters in the composer. The mock refuses anything longer.
  static const int maxCharacters = 500;

  /// Local sample photos the composer may attach. Frontend-only; nothing is
  /// uploaded.
  static const List<String> sampleAttachmentAssets = [
    'assets/portraits/avery.jpg',
    'assets/portraits/jordan.jpg',
    'assets/portraits/riley.jpg',
    'assets/portraits/sam.jpg',
  ];

  /// Short label shown wherever counting or pricing appears.
  static const String mockLabel = 'Mock';

  /// Explains that counting, prices and allocation are simulated.
  static const String mockDisclosure =
      'Mock behaviour: word counting, prices, points and the 80/20 split are '
      'simulated on this device. Nothing is charged, transferred or paid out. '
      'The server will be authoritative later.';

  /// Short dialog copy. Full rules stay in [mockDisclosure].
  static const String mockDialogNote =
      'Simulated word fee, points and 80/20 split. No real money moves.';

  /// Short explainer for the proposed recipient / platform split.
  static const String allocationExplainer =
      '80% of the word fee goes to the recipient and 20% to the platform.';
}

/// Eligible words are whitespace-separated tokens that contain at least one
/// Unicode letter. Punctuation-only tokens, digit-only tokens and empty
/// fragments do not count. Leading and trailing whitespace is ignored, and
/// consecutive whitespace collapses to one split.
///
/// This is the mock rule. A real backend must count for itself and must not
/// trust this function.
int countEligibleWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).where(_tokenHasLetter).length;
}

bool _tokenHasLetter(String token) =>
    token.contains(RegExp(r'\p{L}', unicode: true));

/// 100 points = NPR 1 = 100 paisa, so the mock treats 1 point as 1 paisa.
int pointsFromPaisa(int paisa) => paisa;

/// Local quote for a draft. Display preview only. Never a financial
/// transaction. When an API contract exists the backend quote is
/// authoritative.
class MessageQuote {
  const MessageQuote({
    required this.eligibleWords,
    required this.characterCount,
    required this.costPaisa,
    required this.senderPays,
  });

  factory MessageQuote.fromText(String text, {required bool senderPays}) {
    final words = countEligibleWords(text);
    final paid = senderPays && words > 0;
    return MessageQuote(
      eligibleWords: words,
      characterCount: text.length,
      costPaisa: paid ? words * MessageRules.paisaPerEligibleWord : 0,
      senderPays: senderPays,
    );
  }

  final int eligibleWords;
  final int characterCount;
  final int costPaisa;

  /// True when this account type is charged for eligible words (male, in the
  /// mock). Independent of whether this particular draft has a cost.
  final bool senderPays;

  bool get isPaid => costPaisa > 0;
  bool get tooLong => characterCount > MessageRules.maxCharacters;
  int get costPoints => pointsFromPaisa(costPaisa);

  /// Explanatory mock share only. Remainder goes to [platformSharePaisa] so
  /// the two always sum to [costPaisa].
  int get recipientSharePaisa =>
      (costPaisa * MessageRules.recipientSharePercent) ~/ 100;

  int get platformSharePaisa => costPaisa - recipientSharePaisa;
}
