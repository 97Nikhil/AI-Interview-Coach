// lib/services/ai_feedback_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'apiKeyService.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

class AIFeedbackService {
  static const String _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'deepseek/deepseek-r1:free';
  static const Duration _timeoutDuration = Duration(seconds: 60);

  /// Sends a single question+answer to OpenRouter and expects a strict JSON response.
  /// Returns a Map with keys: rating, must_keywords, grammar_issues, highlights, advice, improved_answer
  static Future<Map<String, dynamic>> getAIFeedback({
    required String question,
    required String answer,
    required String job,
    required String role,
    required String difficulty,
    required int questionIndex,
    String? timestamp,
  }) async {
    try {
      // Validate API key first
      final apiKey = await ApiKeyService.getApiKey();
      if (apiKey == null || apiKey.trim().isEmpty) {
        throw _AIServiceException(
          'API key not configured',
          'Please set up your API key in the User Settings before starting an interview.',
        );
      }

      final systemPrompt =
          '''
You are an objective interview evaluator.
Given the input (question, candidate answer, job, role, difficulty, questionIndex), respond ONLY with a single valid JSON object and nothing else.
The JSON object MUST contain the following keys:
 - rating: number (0-10)
 - must_keywords: array of strings (ALWAYS provide at least 3 key terms/concepts that should be mentioned for a good answer)
 - grammar_issues: array of strings
 - advice: string
 - improved_answer: string

Rules for must_keywords:
1. ALWAYS provide keywords even if the answer is "I don't know" or empty
2. These should be fundamental concepts/terms for answering this question
3. Minimum 3 keywords per question
4. Focus on job-specific terminology from: ${job}

Do NOT include any additional text or explanation.
''';

      final userPayload = {
        'question': question,
        'answer': answer,
        'job': job,
        'role': role,
        'difficulty': difficulty,
        'questionIndex': questionIndex,
        'timestamp': timestamp ?? DateTime.now().toIso8601String(),
      };

      final body = {
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content':
                'Please evaluate the following input and return JSON only: ${jsonEncode(userPayload)}',
          },
        ],
        'temperature': 0.0,
      };

      // Make the API request with timeout
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer':
                  'https://yourdomain.com', // Recommended by OpenRouter
              'X-Title': 'Interview Prep App', // Recommended by OpenRouter
            },
            body: jsonEncode(body),
          )
          .timeout(_timeoutDuration);

      // Handle HTTP errors
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw _AIServiceException(
          'API request failed',
          'Status: ${response.statusCode}. ${_getErrorDescription(response.statusCode, response.body)}',
        );
      }

      // Parse the response
      final decoded = jsonDecode(response.body);
      String? rawContent;

      try {
        rawContent = decoded['choices']?[0]?['message']?['content'] as String?;
      } catch (e) {
        throw _AIServiceException(
          'Invalid response format',
          'Could not extract content from API response: $e',
        );
      }

      if (rawContent == null) {
        throw _AIServiceException(
          'Empty response',
          'The API returned no content in the response',
        );
      }

      // Extract JSON from response
      final jsonText = _extractJson(rawContent);
      if (jsonText == null) {
        throw _AIServiceException(
          'Invalid JSON format',
          'Could not find valid JSON in response: $rawContent',
        );
      }

      final result = jsonDecode(jsonText) as Map<String, dynamic>;
      return result;
    } on http.ClientException catch (e) {
      throw _AIServiceException(
        'Network error',
        'Failed to connect to the API: ${e.message}',
      );
    } on TimeoutException {
      throw _AIServiceException(
        'Request timeout',
        'The API request timed out after ${_timeoutDuration.inSeconds} seconds',
      );
    } on FormatException catch (e) {
      throw _AIServiceException(
        'Data format error',
        'Failed to parse API response: ${e.message}',
      );
    } catch (e) {
      throw _AIServiceException(
        'Unexpected error',
        'An unexpected error occurred: $e',
      );
    }
  }

  static Future<Map<String, dynamic>> analyzeResume({
    required String resumeText,
    required String targetJob,
  }) async {
    final apiKey = await ApiKeyService.getApiKey();
    if (apiKey == null) {
      throw _AIServiceException(
        'API key missing',
        'Please set up your API key in the User Settings before starting analysis.',
      );
    }

    final systemPrompt = '''
You are an ATS resume expert analyzing a resume for a $targetJob role.

Return STRICT JSON with this exact schema:
{
  "score": number (0-100, ATS compatibility),
  "grammar_issues": [
    { "mistake": string, "suggestion": string }
  ],
  "formatting_issues": [
    { "issue": string, "suggestion": string }
  ],
  "missing_keywords": [
    { "keyword": string, "why_important": string }
  ],
  "overall_feedback": string
}

Rules:
1. "score" must be a single number from 0–100.
2. "missing_keywords" must be highly relevant to $targetJob (ignore generic ones like "MS Word").
3. "grammar_issues" should only include actual resume grammar/spelling mistakes.
4. "formatting_issues" should be ATS-related problems (e.g., tables, images, vague section headings).
5. "overall_feedback" must be written as a natural, mentor-like paragraph. Mix positive notes, guidance, small facts (like recruiter behavior/ATS preferences), and suggestions into one flowing explanation. It should feel like the user is getting coached, not judged.
6. Respond ONLY in JSON. No extra text, no explanations.
''';


    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://yourdomain.com',
        'X-Title': 'Resume Analyzer',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': 'Analyze this resume:\n$resumeText'},
        ],
        'temperature': 0.0,
      }),
    ).timeout(_timeoutDuration);

    if (response.statusCode != 200) {
      throw _AIServiceException(
        'API request failed',
        'Status: ${response.statusCode}. ${_getErrorDescription(response.statusCode, response.body)}',
      );
    }

    final jsonText = _extractJson(response.body);
    return jsonDecode(jsonText!) as Map<String, dynamic>;
  }

  static String? _extractJson(String rawContent) {
    try {
      final start = rawContent.indexOf('{');
      final end = rawContent.lastIndexOf('}');
      if (start >= 0 && end > start) {
        return rawContent.substring(start, end + 1);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  static String _getErrorDescription(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded['error']?['message'] ?? body;
    } catch (e) {
      return body;
    }
  }

  static Future<String> extractPdfText(String filePath) async {
    try {
      final text = await ReadPdfText.getPDFtext(filePath);
      if (text.trim().isEmpty) {
        return "No text found in PDF.";
      }
      return text;
    } catch (e) {
      throw Exception("PDF Read Error: ${e.toString()}");
    }
  }
}

class _AIServiceException implements Exception {
  final String title;
  final String message;

  _AIServiceException(this.title, this.message);

  @override
  String toString() => '$title: $message';
}
