import 'package:flutter/services.dart';
import 'package:github_repo/auth/infrastructure/credential_storage/credential_storage.dart';
import 'package:oauth2/oauth2.dart';

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
        secret: clientSecret);
  }

  Uri getAuthorizationUrl(AuthorizationCodeGrant codeGrant) {
    return codeGrant.getAuthorizationUrl(redirectUrl, scopes: scopes);
  }
}
