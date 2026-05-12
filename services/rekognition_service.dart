import 'dart:convert';
import 'dart:io';

import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';
import 'package:http/http.dart' as http;

// ─── Data models ─────────────────────────────────────────────────────────────

class BoundingBox {
  final double width;
  final double height;
  final double left;
  final double top;

  const BoundingBox({
    required this.width,
    required this.height,
    required this.left,
    required this.top,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
    width: (json['Width'] as num).toDouble(),
    height: (json['Height'] as num).toDouble(),
    left: (json['Left'] as num).toDouble(),
    top: (json['Top'] as num).toDouble(),
  );
}

class DetectedLabel {
  final String name;
  final double confidence;
  final List<String> parents;
  final List<BoundingBox> boundingBoxes;

  const DetectedLabel({
    required this.name,
    required this.confidence,
    required this.parents,
    required this.boundingBoxes,
  });

  factory DetectedLabel.fromJson(Map<String, dynamic> json) {
    final instances = json['Instances'] as List<dynamic>? ?? [];
    final parentsJson = json['Parents'] as List<dynamic>? ?? [];
    final boxes = instances
        .where((i) => i['BoundingBox'] != null)
        .map(
          (i) => BoundingBox.fromJson(i['BoundingBox'] as Map<String, dynamic>),
        )
        .toList();
    final parentNames = parentsJson
        .where((p) => p['Name'] != null)
        .map((p) => p['Name'] as String)
        .toList();

    return DetectedLabel(
      name: json['Name'] as String,
      confidence: (json['Confidence'] as num).toDouble(),
      parents: parentNames,
      boundingBoxes: boxes,
    );
  }

  DetectedLabel copyWith({
    String? name,
    double? confidence,
    List<String>? parents,
    List<BoundingBox>? boundingBoxes,
  }) {
    return DetectedLabel(
      name: name ?? this.name,
      confidence: confidence ?? this.confidence,
      parents: parents ?? this.parents,
      boundingBoxes: boundingBoxes ?? this.boundingBoxes,
    );
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class RekognitionService {
  static Future<List<DetectedLabel>> detectLabels({
    required String region,
    required String accessKeyId,
    required String secretKey,
    required String sessionToken,
    required File imageFile,
    int maxLabels = 20,
    double minConfidence = 70.0,
    http.Client? httpClient,
    AWSSigV4Signer? signer,
  }) async {
    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final body = jsonEncode({
      'Image': {'Bytes': base64Image},
      'MaxLabels': maxLabels,
      'MinConfidence': minConfidence,
    });

    final requestSigner =
        signer ??
        AWSSigV4Signer(
          credentialsProvider: AWSCredentialsProvider(
            AWSCredentials(accessKeyId, secretKey, sessionToken),
          ),
        );

    final scope = AWSCredentialScope(
      region: region,
      service: AWSService('rekognition'),
    );

    final endpoint = Uri.https('rekognition.$region.amazonaws.com', '/');

    final awsRequest = AWSHttpRequest.post(
      endpoint,
      body: utf8.encode(body),
      headers: {
        AWSHeaders.contentType: 'application/x-amz-json-1.1',
        'X-Amz-Target': 'RekognitionService.DetectLabels',
      },
    );

    final signedRequest = await requestSigner.sign(
      awsRequest,
      credentialScope: scope,
    );

    final client = httpClient ?? http.Client();
    try {
      final response = await client.post(
        endpoint,
        headers: Map<String, String>.fromEntries(
          signedRequest.headers.entries.map((e) => MapEntry(e.key, e.value)),
        ),
        body: body,
      );

      print('Rekognition DetectLabels raw JSON: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Rekognition error ${response.statusCode}: ${response.body}',
        );
      }

      return parseLabelsFromResponseBody(response.body);
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  static List<DetectedLabel> parseLabelsFromResponseBody(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final labelList = json['Labels'] as List<dynamic>? ?? [];
    final labels = labelList
        .map((l) => DetectedLabel.fromJson(l as Map<String, dynamic>))
        .toList();
    return inheritParentBoundingBoxes(labels);
  }

  static List<DetectedLabel> inheritParentBoundingBoxes(
    List<DetectedLabel> labels,
  ) {
    return labels.map((label) {
      if (label.boundingBoxes.isNotEmpty) return label;

      final inheritedBoxes = labels
          .where((child) => child.parents.contains(label.name))
          .expand((child) => child.boundingBoxes)
          .toList();

      if (inheritedBoxes.isEmpty) return label;
      return label.copyWith(boundingBoxes: inheritedBoxes);
    }).toList();
  }
}
