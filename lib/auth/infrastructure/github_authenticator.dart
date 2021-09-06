import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:github_repo/auth/domain/auth_failure.dart';
import 'package:github_repo/auth/infrastructure/credential_storage/credential_storage.dart';
import 'package:github_repo/core/shared/encoders.dart';
import 'package:oauth2/oauth2.dart';
import 'package:http/http.dart' as http;
import 'package:github_repo/core/infrastructure/dio_extensions.dart';

/*
custom http client to modify header for github
*/
class GithubOAuthHttpClient extends http.BaseClient {
  final httpClient = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Accept'] = 'application/json';
    return httpClient.send(request);
  }
}

class GithubAuthenticator {
  final CredentialsStorage _credentialsStorage;
  final Dio _dio;

  GithubAuthenticator(this._credentialsStorage, this._dio);

  static const clientId = '';
  static const clientSecret = '';
  static const scopes = ['read:user', 'repo'];

  static final authorizationEndpoint =
      Uri.parse('https://github.com/login/oauth/authorize');
  static final tokenEndpoint =
      Uri.parse('https://github.com/login/oauth/access_token');
  static final redirectUrl = Uri.parse('http://localhost:3000/callback');
  static final revocationEndpoint =
      Uri.parse('https://api.github.com/applications/$clientId/token');

  Future<Credentials?> getSignedInCredentials() async {
    try {
      final storageCredentials = await _credentialsStorage.read();

      if (storageCredentials != null) {
        if (storageCredentials.canRefresh && storageCredentials.isExpired) {
          final failureOrCredentials = await refresh(storageCredentials);
          return failureOrCredentials.fold((l) => null, (r) => r);
        }
      }
    } on PlatformException {
      return null;
    }
  }

  Future<bool> isSignedIn() =>
      getSignedInCredentials().then((value) => value != null);

  /*
  1.create the authorization grant
  */
  AuthorizationCodeGrant codeGrant() {
    return AuthorizationCodeGrant(
        clientId, authorizationEndpoint, tokenEndpoint,
        secret: clientSecret, httpClient: GithubOAuthHttpClient());
  }

  /*
  2.get the authorization url once AuthorizationCodeGrant object is created
  */
  Uri getAuthorizationUrl(AuthorizationCodeGrant codeGrant) {
    return codeGrant.getAuthorizationUrl(redirectUrl, scopes: scopes);
  }

  /*
  3. handle authorization for github
  */
  Future<Either<AuthFailure, Unit>> handleAuthorizationResponse(
      AuthorizationCodeGrant codeGrant, Map<String, String> queryParams) async {
    try {
      final httpClient =
          await codeGrant.handleAuthorizationResponse(queryParams);
      await _credentialsStorage.save(httpClient.credentials);
      return right(unit);
    } on FormatException {
      return left(const AuthFailure.server());
    } on AuthorizationException catch (e) {
      return left(AuthFailure.server('${e.error} : ${e.description}'));
    } on PlatformException {
      return left(const AuthFailure.storage());
    }
  }

  Future<Either<AuthFailure, Unit>> signOut() async {
    final accessToken =
        await _credentialsStorage.read().then((value) => value?.accessToken);

    final userNameAndPassword =
        stringToBase64.encode('$clientId:$clientSecret');

    try {
      try {
        _dio.deleteUri(revocationEndpoint,
            data: {
              'access_token': accessToken,
            },
            options: Options(
                headers: {'Authorization': 'basic $userNameAndPassword'}));
      } on DioError catch (e) {
        if (e.isNoConnectionError) {
          //do something
        } else {
          rethrow;
        }
      }

      await _credentialsStorage.clear();
      return right(unit);
    } on PlatformException {
      return left(const AuthFailure.storage());
    }
  }

  Future<Either<AuthFailure, Credentials>> refresh(
      Credentials credentials) async {
    try {
      final refreshCredentials = await credentials.refresh(
        identifier: clientId,
        secret: clientSecret,
        httpClient: GithubOAuthHttpClient(),
      );
      await _credentialsStorage.save(refreshCredentials);
      return right(refreshCredentials);
    } on AuthorizationException catch (e) {
      return left(AuthFailure.server('${e.error} : ${e.description}'));
    } on FormatException {
      return left(const AuthFailure.server());
    } on PlatformException {
      return left(const AuthFailure.storage());
    }
  }
}
