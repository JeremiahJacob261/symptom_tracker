import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:symptom_tracker/services/disease_prediction_service.dart';

void main() {
  test('predict sends the FastAPI contract and parses its response', () async {
    late Uri requestedUri;
    late Map<String, dynamic> requestedBody;
    final client = MockClient((request) async {
      requestedUri = request.url;
      requestedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'possible_match': 'Migraine',
          'confidence': 0.81,
          'alternatives': [
            {'condition': 'Migraine', 'probability': 0.81},
            {'condition': 'Common Cold', 'probability': 0.12},
          ],
          'low_confidence': false,
          'urgent': false,
          'urgent_flags': [],
          'model': 'random_forest',
          'disclaimer': 'Educational result only.',
        }),
        200,
      );
    });
    final service = DiseasePredictionService(
      baseUrl: 'https://example.com/api',
      client: client,
    );

    final result = await service.predict(
      symptomText: 'Throbbing headache with nausea',
      painLevel: 7,
      temperatureCelsius: 37.2,
    );

    expect(requestedUri.toString(), 'https://example.com/api/predict');
    expect(requestedBody['text'], 'Throbbing headache with nausea');
    expect(requestedBody['pain_level'], 7);
    expect(requestedBody['temperature_celsius'], 37.2);
    expect(requestedBody['top_k'], 3);
    expect(result.possibleMatch, 'Migraine');
    expect(result.confidence, 0.81);
    expect(result.alternatives, hasLength(2));
    expect(result.model, 'random_forest');
  });

  test('predict exposes a useful FastAPI error', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'detail': 'Model is not loaded.'}),
        503,
      ),
    );
    final service = DiseasePredictionService(
      baseUrl: 'https://example.com',
      client: client,
    );

    await expectLater(
      service.predict(symptomText: 'Fever and chills'),
      throwsA(
        isA<DiseasePredictionException>().having(
          (error) => error.message,
          'message',
          contains('Model is not loaded'),
        ),
      ),
    );
  });

  test('low-confidence response still exposes its closest pattern', () {
    final result = DiseasePredictionResult.fromJson({
      'possible_match': null,
      'confidence': 0.39,
      'alternatives': [
        {'condition': 'urinary tract infection', 'probability': 0.39},
        {'condition': 'diabetes', 'probability': 0.20},
      ],
      'low_confidence': true,
      'urgent': false,
      'urgent_flags': [],
      'model': 'random_forest',
      'disclaimer': 'Educational result only.',
    });

    expect(result.lowConfidence, isTrue);
    expect(result.closestPattern, 'urinary tract infection');
    expect(result.alternatives, hasLength(2));
  });

  test('health uses the configured base path', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'ok': true,
          'selected_model': 'random_forest',
          'dataset': 'Symptom2Disease',
          'classes': 24,
        }),
        200,
      );
    });
    final service = DiseasePredictionService(
      baseUrl: 'https://example.com/backend/',
      client: client,
    );

    final health = await service.health();

    expect(requestedUri.toString(), 'https://example.com/backend/health');
    expect(health['ok'], isTrue);
    expect(health['classes'], 24);
  });
}
