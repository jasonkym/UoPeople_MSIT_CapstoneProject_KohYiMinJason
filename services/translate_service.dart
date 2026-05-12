import 'dart:convert';

import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';
import 'package:http/http.dart' as http;

// ─── Data models ─────────────────────────────────────────────────────────────

class TranslatedResult {
  final String sourceLanguage;
  final String targetLanguage;
  final String translatedText;

  const TranslatedResult({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.translatedText,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

class TranslateService {
  static Future<List<TranslatedResult>> translateText({
    required String region,
    required String accessKeyId,
    required String secretKey,
    required String sessionToken,
    required String text,
    String sourceLanguage = 'auto',
    required List<String> targetLanguages,
    http.Client? httpClient,
    AWSSigV4Signer? signer,
  }) async {
    final results = <TranslatedResult>[];
    final requestSigner =
        signer ??
        AWSSigV4Signer(
          credentialsProvider: AWSCredentialsProvider(
            AWSCredentials(accessKeyId, secretKey, sessionToken),
          ),
        );
    final endpoint = Uri.https('translate.$region.amazonaws.com', '/');
    final scope = AWSCredentialScope(
      region: region,
      service: AWSService('translate'),
    );
    final client = httpClient ?? http.Client();

    try {
      for (final targetLang in targetLanguages) {
        final body = jsonEncode({
          'Text': text,
          'SourceLanguageCode': sourceLanguage,
          'TargetLanguageCode': targetLang,
        });
        final awsRequest = AWSHttpRequest.post(
          endpoint,
          body: utf8.encode(body),
          headers: {
            AWSHeaders.contentType: 'application/x-amz-json-1.1',
            'X-Amz-Target': 'AWSShineFrontendService_20170701.TranslateText',
          },
        );
        final signedRequest = await requestSigner.sign(
          awsRequest,
          credentialScope: scope,
        );
        final response = await client.post(
          endpoint,
          headers: Map<String, String>.fromEntries(
            signedRequest.headers.entries.map((e) => MapEntry(e.key, e.value)),
          ),
          body: body,
        );
        if (response.statusCode != 200) {
          throw Exception(
            'Translate error ${response.statusCode}: ${response.body}',
          );
        }
        final translatedText = parseTranslatedTextFromResponseBody(
          response.body,
        );
        print('Translate response for $targetLang: ${response.body}');
        results.add(
          TranslatedResult(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLang,
            translatedText: translatedText,
          ),
        );
      }

      return results;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  static String parseTranslatedTextFromResponseBody(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['TranslatedText'] as String? ?? '';
  }
}
