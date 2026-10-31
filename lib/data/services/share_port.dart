import 'package:share_plus/share_plus.dart';

/// Thin wrapper around Flutter's share sheet so tests can record the payload
/// without opening a system dialog.
abstract class SharePort {
  Future<void> shareText(String text);
}

class SystemSharePort implements SharePort {
  const SystemSharePort();

  @override
  Future<void> shareText(String text) {
    return SharePlus.instance.share(ShareParams(text: text));
  }
}
