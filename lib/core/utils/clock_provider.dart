import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time, injectable so age checks and session expiry are testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
