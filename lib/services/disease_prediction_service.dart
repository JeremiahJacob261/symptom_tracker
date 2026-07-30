import 'dart:convert';

import 'package:http/http.dart' as http;

class DiseasePredictionAlternative {
  const DiseasePredictionAlternative({
    required this.condition,
    required this.probability,
  });

  final String condition;
  final double probability;

  factory DiseasePredictionAlternative.fromJson(Map<String, dynamic> json) {
    return DiseasePredictionAlternative(
      condition: json['condition']?.toString() ?? 'Unknown',
      probability: (json['probability'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DiseasePredictionResult {
  const DiseasePredictionResult({
    required this.possibleMatch,
    required this.confidence,
    required this.alternatives,
    required this.lowConfidence,
    required this.urgent,
    required this.urgentFlags,
    required this.model,
    required this.disclaimer,
  });

  final String? possibleMatch;
  final double confidence;
  final List<DiseasePredictionAlternative> alternatives;
  final bool lowConfidence;
  final bool urgent;
  final List<String> urgentFlags;
  final String model;
  final String disclaimer;

  /// The confident match when available, otherwise the model's closest
  /// low-confidence alternative. This is for transparent display only.
  String? get closestPattern {
    if (possibleMatch != null && possibleMatch!.trim().isNotEmpty) {
      return possibleMatch;
    }
    return alternatives.isEmpty ? null : alternatives.first.condition;
  }

  factory DiseasePredictionResult.fromJson(Map<String, dynamic> json) {
    final rawAlternatives = json['alternatives'];
    return DiseasePredictionResult(
      possibleMatch: json['possible_match']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      alternatives: rawAlternatives is List
          ? rawAlternatives
              .whereType<Map>()
              .map(
                (item) => DiseasePredictionAlternative.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const [],
      lowConfidence: json['low_confidence'] == true,
      urgent: json['urgent'] == true,
      urgentFlags: (json['urgent_flags'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      model: json['model']?.toString() ?? 'unknown',
      disclaimer:
          json['disclaimer']?.toString() ?? 'This is not a medical diagnosis.',
    );
  }
}

class DiseasePredictionException implements Exception {
  const DiseasePredictionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DiseasePredictionService {
  DiseasePredictionService({
    required String baseUrl,
    http.Client? client,
    // Modal can take several seconds to start a cold container and load the
    // 101 MB Random Forest artifact. Keep the first real prediction from
    // being treated as a network failure while retaining a bounded request.
    this.timeout = const Duration(seconds: 45),
  })  : baseUrl = baseUrl.trim(),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Persistent Modal deployment of the bundled Random Forest classifier.
  ///
  /// A build can still point to another compatible backend with
  /// `--dart-define=SYMPTOM_MODEL_API_URL=...`.
  static const deployedModalBaseUrl =
      'https://akpomoshix--symptom-tracker-ml-web.modal.run';

  static const configuredBaseUrl = String.fromEnvironment(
    'SYMPTOM_MODEL_API_URL',
    defaultValue: deployedModalBaseUrl,
  );

  static bool get isConfigured => configuredBaseUrl.trim().isNotEmpty;

  static DiseasePredictionService fromEnvironment() {
    if (!isConfigured) {
      throw const DiseasePredictionException(
        'SYMPTOM_MODEL_API_URL is not configured.',
      );
    }
    return DiseasePredictionService(baseUrl: configuredBaseUrl);
  }

  final String baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Uri _endpoint(String endpoint) {
    if (baseUrl.isEmpty) {
      throw const DiseasePredictionException(
        'The symptom model API URL is empty.',
      );
    }

    final base = Uri.tryParse(baseUrl);
    if (base == null || !base.hasScheme || base.host.isEmpty) {
      throw const DiseasePredictionException(
        'The symptom model API URL is invalid.',
      );
    }

    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final endpointPath = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return base.replace(
      path: '$basePath$endpointPath',
      query: null,
      fragment: null,
    );
  }

  Future<Map<String, dynamic>> health() async {
    try {
      final response = await _client.get(_endpoint('/health')).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DiseasePredictionException(
          'Health check failed with status ${response.statusCode}.',
        );
      }
      return _decodeObject(response.body);
    } on DiseasePredictionException {
      rethrow;
    } on http.ClientException {
      throw const DiseasePredictionException(
        'Could not reach the symptom model service.',
      );
    } on FormatException {
      throw const DiseasePredictionException(
        'The symptom model returned an invalid response.',
      );
    } catch (_) {
      throw const DiseasePredictionException(
        'The symptom model request timed out or failed.',
      );
    }
  }

  Future<DiseasePredictionResult> predict({
    required String symptomText,
    int? painLevel,
    double? temperatureCelsius,
    int topK = 3,
  }) async {
    final text = symptomText.trim();
    if (text.length < 3) {
      throw const DiseasePredictionException(
        'Enter more symptom details before running the model.',
      );
    }

    try {
      final response = await _client
          .post(
            _endpoint('/predict'),
            headers: const {
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'text': text,
              if (painLevel != null) 'pain_level': painLevel,
              if (temperatureCelsius != null)
                'temperature_celsius': temperatureCelsius,
              'top_k': topK.clamp(1, 5),
            }),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _errorDetail(response.body);
        throw DiseasePredictionException(
          detail == null
              ? 'Prediction failed with status ${response.statusCode}.'
              : 'Prediction failed: $detail',
        );
      }

      return DiseasePredictionResult.fromJson(_decodeObject(response.body));
    } on DiseasePredictionException {
      rethrow;
    } on http.ClientException {
      throw const DiseasePredictionException(
        'Could not reach the symptom model service.',
      );
    } on FormatException {
      throw const DiseasePredictionException(
        'The symptom model returned an invalid response.',
      );
    } catch (_) {
      throw const DiseasePredictionException(
        'The symptom model request timed out or failed.',
      );
    }
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String? _errorDetail(String body) {
    try {
      final decoded = _decodeObject(body);
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      if (detail is List && detail.isNotEmpty) return detail.first.toString();
    } catch (_) {
      return null;
    }
    return null;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
