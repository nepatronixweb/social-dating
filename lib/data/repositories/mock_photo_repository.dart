import 'dart:typed_data';

import '../../core/constants/message_rules.dart';
import '../../core/errors/app_failure.dart';
import '../models/profile_photo.dart';
import 'photo_repository.dart';

/// In-memory photos using bundled sample portraits. Upload ignores bytes.
class MockPhotoRepository implements PhotoRepository {
  MockPhotoRepository({this.latency = const Duration(milliseconds: 80)});

  final Duration latency;
  final List<ProfilePhoto> _items = [
    const ProfilePhoto(
      id: 'mock-photo-1',
      source: 'assets/portraits/avery.jpg',
      sortOrder: 0,
    ),
  ];
  int _next = 2;

  Future<void> _wait() => Future<void>.delayed(latency);

  @override
  Future<List<ProfilePhoto>> fetchMine() async {
    await _wait();
    return List.unmodifiable(_items);
  }

  @override
  Future<ProfilePhoto> upload({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    await _wait();
    if (_items.length >= 6) {
      throw const ValidationFailure('You already have six photos.');
    }
    const samples = MessageRules.sampleAttachmentAssets;
    final photo = ProfilePhoto(
      id: 'mock-photo-$_next',
      source: samples[_items.length % samples.length],
      sortOrder: _items.length,
    );
    _next++;
    _items.add(photo);
    return photo;
  }

  @override
  Future<void> reorder(List<String> ids) async {
    await _wait();
    if (ids.length != _items.length || ids.toSet().length != ids.length) {
      throw const ValidationFailure('Send every photo id exactly once.');
    }
    final byId = {for (final item in _items) item.id: item};
    final next = <ProfilePhoto>[];
    for (var i = 0; i < ids.length; i++) {
      final existing = byId[ids[i]];
      if (existing == null) {
        throw const NotFoundFailure('That photo is not on your profile.');
      }
      next.add(
        ProfilePhoto(id: existing.id, source: existing.source, sortOrder: i),
      );
    }
    _items
      ..clear()
      ..addAll(next);
  }

  @override
  Future<void> delete(String id) async {
    await _wait();
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw const NotFoundFailure('That photo is not on your profile.');
    }
    _items.removeAt(index);
    for (var i = 0; i < _items.length; i++) {
      _items[i] = ProfilePhoto(
        id: _items[i].id,
        source: _items[i].source,
        sortOrder: i,
      );
    }
  }
}
