import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/errors/app_failure.dart';
import '../api/auth_paths.dart';
import '../api/page.dart';
import '../api/photo_paths.dart';
import '../dto/auth_dtos.dart';
import '../dto/photo_dtos.dart';
import '../models/profile_photo.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';
import 'photo_repository.dart';

class ApiPhotoRepository implements PhotoRepository {
  ApiPhotoRepository({required ApiClient client, required TokenStorage tokens})
    : _dio = client.dio,
      _tokens = tokens;

  final Dio _dio;
  final TokenStorage _tokens;

  @override
  Future<List<ProfilePhoto>> fetchMine() {
    return _withSession(
      () => _dio.get<dynamic>(PhotoApiPaths.mine),
      (response) => Page.fromJson(
        response.data,
        (item) => PhotoDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<ProfilePhoto> upload({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) {
    final data = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _withSession(
      () => _dio.post<dynamic>(PhotoApiPaths.mine, data: data),
      (response) => PhotoDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<void> reorder(List<String> ids) {
    return _withSession(
      () => _dio.patch<dynamic>(PhotoApiPaths.order, data: {'ids': ids}),
      (_) {},
    );
  }

  @override
  Future<void> delete(String id) {
    return _withSession(
      () => _dio.delete<dynamic>(PhotoApiPaths.one(id)),
      (_) {},
    );
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
