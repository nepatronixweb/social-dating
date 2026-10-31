import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/api_error_mapper.dart';
import '../dto/json_codec.dart';

/// Cursor pagination for list endpoints. Limit is a hint; the server decides
/// the page size it will honour.
@immutable
class PageRequest {
  const PageRequest({this.cursor, this.limit = defaultLimit, this.cancelToken});

  static const int defaultLimit = 20;
  static const int maxLimit = 100;

  final String? cursor;
  final int limit;

  /// Cancels the in-flight Dio call when the widget is disposed.
  final CancelToken? cancelToken;

  int get clampedLimit {
    if (limit < 1) return 1;
    if (limit > maxLimit) return maxLimit;
    return limit;
  }

  Map<String, Object?> toQuery() => {
    if (cursor != null && cursor!.isNotEmpty) 'cursor': cursor,
    'limit': clampedLimit,
  };
}

/// One page of [items]. [nextCursor] is opaque; the client must not parse it.
@immutable
class Page<T> {
  const Page({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory Page.fromJson(
    Object? json,
    T Function(JsonMap item) parseItem, {
    String itemsKey = 'items',
  }) {
    final map = JsonMap.from(json);
    final list = map.value(itemsKey);
    if (list is! List) {
      throw JsonFormatException('Expected an array at \$.$itemsKey.');
    }
    final items = <T>[
      for (var i = 0; i < list.length; i++)
        parseItem(JsonMap.from(list[i], path: '\$.$itemsKey[$i]')),
    ];
    return Page(items: items, nextCursor: map.optionalString('nextCursor'));
  }

  Map<String, Object?> toJson(Object? Function(T item) itemToJson) => {
    'items': [for (final item in items) itemToJson(item)],
    'nextCursor': nextCursor,
  };
}
