import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

abstract class AuthenticationClient {
  Future<SignInResult> signIn({
    required String username,
    required String password,
  });

  Future<SignOutResult> signOut();

  Future<({String accessKey, String secretKey, String sessionToken})>
  fetchAwsCredentials({bool forceRefresh = false});
}

class AmplifyAuthenticationClient implements AuthenticationClient {
  @override
  Future<SignInResult> signIn({
    required String username,
    required String password,
  }) {
    return Amplify.Auth.signIn(username: username, password: password);
  }

  @override
  Future<SignOutResult> signOut() {
    return Amplify.Auth.signOut();
  }

  @override
  Future<({String accessKey, String secretKey, String sessionToken})>
  fetchAwsCredentials({bool forceRefresh = false}) async {
    final session =
        await Amplify.Auth.fetchAuthSession(
              options: FetchAuthSessionOptions(forceRefresh: forceRefresh),
            )
            as CognitoAuthSession;

    final creds = session.credentialsResult.value;
    return (
      accessKey: creds.accessKeyId,
      secretKey: creds.secretAccessKey,
      sessionToken: creds.sessionToken ?? '',
    );
  }
}

class AuthenticationService {
  static final AuthenticationClient _defaultClient =
      AmplifyAuthenticationClient();

  /// Sign in user with username and password using AWS Cognito
  static Future<SignInResult> signIn({
    required String username,
    required String password,
    AuthenticationClient? client,
  }) async {
    final sanitizedUsername = username.trim();
    final authClient = client ?? _defaultClient;
    try {
      return await authClient.signIn(
        username: sanitizedUsername,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out the current user
  static Future<SignOutResult> signOut({AuthenticationClient? client}) async {
    final authClient = client ?? _defaultClient;
    try {
      return await authClient.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Get temporary AWS credentials from Cognito Identity Pool
  static Future<({String accessKey, String secretKey, String sessionToken})>
  getAwsCredentials({AuthenticationClient? client}) async {
    final authClient = client ?? _defaultClient;
    try {
      return await authClient.fetchAwsCredentials();
    } catch (e) {
      rethrow;
    }
  }
}
