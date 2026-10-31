import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/utils/media_url.dart';
import 'package:social_dating/data/repositories/mock_photo_repository.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/profile/presentation/profile_photos_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  group('media URLs', () {
    test('relative paths take the supplied origin', () {
      final uri = resolveMediaUrl(
        '/v1/media/abc?e=1&s=x',
        origin: 'http://media.test',
      );
      expect(uri.toString(), 'http://media.test/v1/media/abc?e=1&s=x');
    });

    test('asset paths stay local images', () {
      expect(
        profileImageProvider('assets/portraits/avery.jpg'),
        isA<AssetImage>(),
      );
      expect(profileImageProvider('/v1/media/abc'), isNull);
    });
  });

  group('mock photo repository', () {
    test('upload, reorder and delete', () async {
      final repo = MockPhotoRepository(latency: Duration.zero);
      expect((await repo.fetchMine()), hasLength(1));

      final added = await repo.upload(
        bytes: Uint8List(0),
        filename: 'next.jpg',
      );
      var items = await repo.fetchMine();
      expect(items, hasLength(2));
      expect(items.last.id, added.id);

      await repo.reorder([added.id, 'mock-photo-1']);
      items = await repo.fetchMine();
      expect(items.first.id, added.id);
      expect(items.first.sortOrder, 0);

      await repo.delete(added.id);
      items = await repo.fetchMine();
      expect(items, hasLength(1));
      expect(items.single.id, 'mock-photo-1');
      expect(items.single.sortOrder, 0);
    });
  });

  testWidgets('photos screen lists the mock main photo', (tester) async {
    usePhoneScreen(tester);
    await pumpApp(
      tester,
      location: AppRoutes.profilePhotos,
      session: AuthStatus.loggedIn,
    );
    await pumpFrames(tester);
    expect(find.byType(ProfilePhotosScreen), findsOneWidget);
    expect(find.text('Main photo'), findsOneWidget);
    expect(find.text('Add a photo'), findsOneWidget);
  });
}
