import '../../core/errors/api_error_mapper.dart';

/// Strict JSON object reader for proposed API DTOs.
///
/// Money, points and counts must be JSON integers. Floating-point values are
/// rejected so a rupee/paisa mix-up cannot silently round.
final class JsonMap {
  JsonMap(this._raw, {this.path = r'$'});

  final Map<String, Object?> _raw;
  final String path;

  static JsonMap from(Object? json, {String path = r'$'}) {
    if (json is! Map) {
      throw JsonFormatException('Expected an object at $path.');
    }
    return JsonMap({
      for (final entry in json.entries) entry.key.toString(): entry.value,
    }, path: path);
  }

  bool contains(String key) => _raw.containsKey(key) && _raw[key] != null;

  Object? value(String key) => _raw[key];

  String string(String key, {bool allowEmpty = false}) {
    final raw = _raw[key];
    if (raw is! String) {
      throw JsonFormatException('Expected a string at $path.$key.');
    }
    if (!allowEmpty && raw.isEmpty) {
      throw JsonFormatException('Expected a non-empty string at $path.$key.');
    }
    return raw;
  }

  String? optionalString(String key, {bool allowEmpty = false}) {
    if (!contains(key)) return null;
    return string(key, allowEmpty: allowEmpty);
  }

  int integer(String key) {
    final raw = _raw[key];
    if (raw is int) return raw;
    if (raw is num) {
      throw JsonFormatException(
        'Expected an integer at $path.$key. Fractional JSON numbers are not '
        'allowed for money, points, counts or identifiers.',
      );
    }
    throw JsonFormatException('Expected an integer at $path.$key.');
  }

  int? optionalInteger(String key) {
    if (!contains(key)) return null;
    return integer(key);
  }

  bool boolean(String key) {
    final raw = _raw[key];
    if (raw is bool) return raw;
    throw JsonFormatException('Expected a boolean at $path.$key.');
  }

  bool? optionalBoolean(String key) {
    if (!contains(key)) return null;
    return boolean(key);
  }

  DateTime dateTime(String key) {
    final raw = string(key);
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw JsonFormatException(
        'Expected an ISO-8601 date-time at $path.$key.',
      );
    }
    return parsed.toUtc();
  }

  DateTime? optionalDateTime(String key) {
    if (!contains(key)) return null;
    return dateTime(key);
  }

  T enumValue<T extends Enum>(String key, List<T> values) {
    final raw = string(key);
    for (final value in values) {
      if (value.name == raw) return value;
    }
    throw JsonFormatException('Unknown ${T.toString()} "$raw" at $path.$key.');
  }

  T? optionalEnum<T extends Enum>(String key, List<T> values) {
    if (!contains(key)) return null;
    return enumValue(key, values);
  }

  /// Copy of the underlying entries. For passing a nested object to a DTO.
  Map<String, Object?> asMap() => Map<String, Object?>.from(_raw);

  JsonMap object(String key) => from(_raw[key], path: '$path.$key');

  JsonMap? optionalObject(String key) {
    if (!contains(key)) return null;
    return object(key);
  }

  List<JsonMap> objectList(String key) {
    final raw = _raw[key];
    if (raw is! List) {
      throw JsonFormatException('Expected an array at $path.$key.');
    }
    return [
      for (var i = 0; i < raw.length; i++)
        JsonMap.from(raw[i], path: '$path.$key[$i]'),
    ];
  }

  List<String> stringList(String key) {
    final raw = _raw[key];
    if (raw is! List) {
      throw JsonFormatException('Expected an array at $path.$key.');
    }
    return [
      for (var i = 0; i < raw.length; i++)
        JsonMap({key: raw[i]}, path: '$path.$key[$i]').string(key),
    ];
  }

  /// Client display objects must not include private fields.
  void rejectPrivateFields(Iterable<String> keys) {
    for (final key in keys) {
      if (_raw.containsKey(key) && _raw[key] != null) {
        throw JsonFormatException(
          'Private field "$key" must not be sent to the client at $path.',
        );
      }
    }
  }
}
