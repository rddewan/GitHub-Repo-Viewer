import 'package:flutter/services.dart';
import 'package:github_repo/auth/infrastructure/credential_storage/credential_storage.dart';
import 'package:oauth2/oauth2.dart';

class GithubAuthenticator {
  final CredentialsStorage _credentialsStorage;

  GithubAuthenticator(this._credentialsStorage);

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
}
