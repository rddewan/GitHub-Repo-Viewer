import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:github_repo/auth/domain/auth_failure.dart';
import 'package:github_repo/auth/infrastructure/credential_storage/credential_storage.dart';
import 'package:oauth2/oauth2.dart';
import 'package:http/http.dart' as http;

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

  GithubAuthenticator(this._credentialsStorage);

  static const clientId = '';
  static const clientSecret = '';
  static const scopes = ['read:user', 'repo'];

  static final authorizationEndpoint =
      Uri.parse('https://github.com/login/oauth/authorize');
  static final tokenEndpoint =
      Uri.parse('https://github.com/login/oauth/access_token');
  static final redirectUrl = Uri.parse('http://localhost:3000/callback');

  Future<Credentials?> getSignedInCredentials() async {
    try {
      final storageCredentials = await _credentialsStorage.read();

      if (storageCredentials != null) {
        if (storageCredentials.canRefresh && storageCredentials.isExpired) {
          //TODO: refresh
        }
      }
    } on PlatformException {
      return null;
    }
  }

  Future<bool> isSignedIn() =>
      getSignedInCredentials().then((value) => value != null);

  AuthorizationCodeGrant codeGrant() {
    return AuthorizationCodeGrant(
        clientId, authorizationEndpoint, tokenEndpoint,
        secret: clientSecret,
        httpClient: GithubOAuthHttpClient());
  }

  Uri getAuthorizationUrl(AuthorizationCodeGrant codeGrant) {
    return codeGrant.getAuthorizationUrl(redirectUrl, scopes: scopes);
  }

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
}
