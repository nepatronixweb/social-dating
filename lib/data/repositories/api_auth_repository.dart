import 'package:dio/dio.dart';

import '../../core/errors/app_failure.dart';
import '../api/auth_paths.dart';
import '../dto/auth_dtos.dart';
import '../models/account_state.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';
import 'auth_repository.dart';

/// Live authentication against the confirmed `/v1` contract.
///
/// Tokens stay in [TokenStorage]. This client does not special-case a code;
/// the API accepts the static development OTP until SMS is enabled.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required ApiClient client, required TokenStorage tokens})
    : _dio = client.dio,
      _tokens = tokens;

  final Dio _dio;
  final TokenStorage _tokens;

  static final Options _emptyBody = Options(responseType: ResponseType.plain);

  @override
  String? get developmentNotice => null;

  @override
  List<String>? get developmentTestInputs => null;

  @override
  Future<bool> requestCode(String phone) async {
    try {
      final response = await _dio.post<dynamic>(
        AuthApiPaths.requestCode,
        data: RequestCodeRequestDto(e164Phone: phone).toJson(),
      );
      return RequestCodeResponseDto.fromJson(response.data).registered;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<AccountState> verifyCode({
    required String phone,
    required String code,
    String? resumeAccountId,
    String? referralCode,
    bool login = false,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        AuthApiPaths.verify,
        data: {
          'phone': phone,
          'code': code,
          if (login) 'login': true,
          if (referralCode != null && referralCode.isNotEmpty)
            'referralCode': referralCode,
        },
      );
      return await _persistSession(
        AuthVerifyResponseDto.fromJson(response.data),
      );
    } catch (error) {
      throw _mapVerifyFailure(error);
    }
  }

  @override
  Future<AccountState> acceptTerms(String accountId) {
    return _readMe(() => _dio.post<dynamic>(AuthApiPaths.terms));
  }

  @override
  Future<AccountState> submitBirthDate(String accountId, DateTime birthDate) {
    return _readMe(
      () => _dio.post<dynamic>(
        AuthApiPaths.age,
        data: SubmitAgeRequestDto(birthDate: birthDate).toJson(),
      ),
    );
  }

  @override
  Future<AccountState> setGender(String accountId, String gender) {
    return _readMe(
      () => _dio.post<dynamic>(
        AuthApiPaths.gender,
        data: SetGenderRequestDto(gender: gender).toJson(),
      ),
    );
  }

  @override
  Future<AccountState> completeProfile(
    String accountId,
    String displayName, {
    String bio = '',
    List<String> interests = const [],
    String? city,
    String? gender,
  }) {
    return _readMe(
      () => _dio.post<dynamic>(
        AuthApiPaths.profile,
        data: CompleteProfileRequestDto(
          displayName: displayName,
          bio: bio,
          interests: interests,
          city: city,
          gender: gender,
        ).toJson(),
      ),
    );
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    await _withSession(
      () => _dio.delete<dynamic>(AuthApiPaths.me, options: _emptyBody),
      read: (_) {},
    );
    await _tokens.clear();
  }

  @override
  Future<void> signOut() async {
    final access = await _tokens.readAccessToken();
    final refresh = await _tokens.readRefreshToken();
    try {
      if (access != null && access.isNotEmpty) {
        await _dio.post<dynamic>(
          AuthApiPaths.signOut,
          data: (refresh == null || refresh.isEmpty)
              ? null
              : RefreshRequestDto(refreshToken: refresh).toJson(),
          options: _emptyBody.copyWith(
            headers: {'Authorization': 'Bearer $access'},
          ),
        );
      }
    } catch (_) {
      // Local session still ends.
    } finally {
      final stillSame = await _tokens.readAccessToken();
      if (stillSame == access) {
        await _tokens.clear();
      }
    }
  }

  Future<AccountState> _readMe(Future<Response<dynamic>> Function() send) {
    return _withSession(send, read: _readAccount);
  }

  Future<T> _withSession<T>(
    Future<Response<dynamic>> Function() send, {
    required T Function(Response<dynamic> response) read,
  }) async {
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
      await _persistSession(AuthVerifyResponseDto.fromJson(response.data));
    } catch (error) {
      await _tokens.clear();
      throw AppFailure.from(error);
    }
  }

  Future<AccountState> _persistSession(AuthVerifyResponseDto dto) async {
    final access = dto.accessToken;
    final refresh = dto.refreshToken;
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      throw const ServerFailure();
    }
    await _tokens.writeSession(accessToken: access, refreshToken: refresh);
    return dto.account.toDomain();
  }

  AccountState _readAccount(Response<dynamic> response) =>
      AccountStateDto.fromJson(response.data).toDomain();

  Future<void> _send(Future<Response<dynamic>> Function() send) async {
    try {
      await send();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  static AppFailure _mapVerifyFailure(Object error) {
    final mapped = AppFailure.from(error);
    if (mapped is! UnauthorizedFailure) return mapped;
    final message = mapped.message.toLowerCase();
    if (message.contains('request a new') || message.contains('expired')) {
      return CodeExpiredFailure(mapped.message);
    }
    if (mapped.message == 'Please sign in again.') {
      return const InvalidCodeFailure();
    }
    return InvalidCodeFailure(mapped.message);
  }
}
