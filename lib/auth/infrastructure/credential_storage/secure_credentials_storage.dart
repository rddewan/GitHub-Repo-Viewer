import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:github_repo/auth/infrastructure/credential_storage/credential_storage.dart';
import 'package:oauth2/src/credentials.dart';

class SecureCredentialsStorage implements CredentialsStorage {
  final FlutterSecureStorage _storage;

  SecureCredentialsStorage(this._storage);

  static const _key = 'oauth2_credentials';
  Credentials? _cacheCredentials;

  @override
  Future<Credentials?> read() async {
    if (_cacheCredentials != null) {
      return _cacheCredentials;
    }

    final json = await _storage.read(key: _key);

    if (json == null) {
      return null;
    }

    try {
      return _cacheCredentials = Credentials.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(Credentials credentials) {
    _cacheCredentials = credentials;
    return _storage.write(key: _key, value: credentials.toJson());
  }

  @override
  Future<void> clear() {
    _cacheCredentials = null;
    return _storage.delete(key: _key);
  }
}
