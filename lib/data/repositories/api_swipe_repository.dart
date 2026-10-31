import 'package:dio/dio.dart';

import '../../core/errors/app_failure.dart';
import '../api/auth_paths.dart';
import '../api/discovery_paths.dart';
import '../api/page.dart';
import '../dto/auth_dtos.dart';
import '../dto/profile_dtos.dart';
import '../dto/typed_values.dart';
import '../models/discovery_filters.dart';
import '../models/profile.dart';
import '../models/swipe.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';
import 'swipe_repository.dart';

class ApiSwipeRepository implements SwipeRepository {
  ApiSwipeRepository({required ApiClient client, required TokenStorage tokens})
    : _dio = client.dio,
      _tokens = tokens;

  final Dio _dio;
  final TokenStorage _tokens;

  @override
  Future<List<Profile>> fetchDeck(DiscoveryFilters filters) {
    return _withSession(
      () => _dio.get<dynamic>(
        DiscoveryApiPaths.candidates,
        queryParameters: {
          'minAge': filters.minAge,
          'maxAge': filters.maxAge,
          'showMe': filters.showMe.name,
          'verifiedOnly': filters.verifiedOnly,
          if (filters.interests.isNotEmpty)
            'interests': (filters.interests.toList()..sort()).join(','),
        },
      ),
      (response) => Page.fromJson(
        response.data,
        (item) => DiscoveryCandidateDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<SwipeQuota> fetchQuota() {
    return _withSession(
      () => _dio.get<dynamic>(DiscoveryApiPaths.quota),
      (response) => SwipeQuotaDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<SwipeOutcome> swipe(
    String profileId,
    SwipeDirection direction, {
    required bool confirmedPaid,
  }) {
    return _withSession(
      () => _dio.post<dynamic>(
        DiscoveryApiPaths.swipes,
        data: SwipeRequestDto(
          profileId: ProfileId(profileId),
          direction: direction,
          confirmedPaid: confirmedPaid,
        ).toJson(),
      ),
      (response) => SwipeOutcomeDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<UndoOutcome?> undoLast() {
    return _withSession(() => _dio.post<dynamic>(DiscoveryApiPaths.undo), (
      response,
    ) {
      if (response.statusCode == 204) return null;
      final data = response.data;
      if (data == null || (data is String && data.isEmpty)) return null;
      return UndoOutcomeDto.fromJson(data).toDomain();
    });
  }

  Future<T> _withSession<T>(
    Future<Response<dynamic>> Function() send,
    T Function(Response<dynamic> response) read,
  ) async {
    try {
      return read(await send());
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw AppFailure.from(error);
      }
      await _refresh();
      try {
        return read(await send());
      } catch (retryError) {
        throw AppFailure.from(retryError);
      }
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> _refresh() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw const UnauthorizedFailure();
    }
    try {
      final response = await _dio.post<dynamic>(
        AuthApiPaths.refresh,
        data: RefreshRequestDto(refreshToken: refresh).toJson(),
      );
      final dto = AuthVerifyResponseDto.fromJson(response.data);
      final access = dto.accessToken;
      final next = dto.refreshToken;
      if (access == null || next == null) {
        throw const UnauthorizedFailure();
      }
      await _tokens.writeSession(accessToken: access, refreshToken: next);
    } catch (error) {
      await _tokens.clear();
      throw AppFailure.from(error);
    }
  }
}
