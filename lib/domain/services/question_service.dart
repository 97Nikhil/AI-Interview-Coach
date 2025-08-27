// question_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:developer' as developer;

class QuestionService {
  static Future<List<String>> loadQuestions(String job, String difficulty, String role) async {
    try {
      final jsonString = await rootBundle.loadString('lib/data/interview_questions.json');
      final data = jsonDecode(jsonString);
      final all = (data['questions'] as List<dynamic>?) ?? [];

      // Find matching group
      final matchingGroup = all.firstWhere(
            (group) =>
        (group['job']?.toString().toLowerCase().trim() == job.toLowerCase().trim()) &&
            (group['difficulty']?.toString().toLowerCase().trim() == difficulty.toLowerCase().trim()) &&
            (group['role']?.toString().toLowerCase().trim() == role.toLowerCase().trim()),
        orElse: () => null,
      );

      List<String> questions = [];

      if (matchingGroup != null && matchingGroup['text'] is List) {
        // Handle the case where text is an array of questions
        questions = List<String>.from(matchingGroup['text'].map((q) => q.toString()));
      } else if (matchingGroup != null && matchingGroup['text'] is String) {
        // Handle legacy format where text is a single string
        questions = [matchingGroup['text'].toString()];
      }

      // Fallback 1: Job + Difficulty
      if (questions.isEmpty) {
        final fallbackGroup = all.firstWhere(
              (group) =>
          (group['job']?.toString().toLowerCase().trim() == job.toLowerCase().trim()) &&
              (group['difficulty']?.toString().toLowerCase().trim() == difficulty.toLowerCase().trim()),
          orElse: () => null,
        );
        if (fallbackGroup != null && fallbackGroup['text'] is List) {
          questions = List<String>.from(fallbackGroup['text'].map((q) => q.toString()));
        }
      }

      // Fallback 2: Just Job
      if (questions.isEmpty) {
        final fallbackGroup = all.firstWhere(
              (group) => (group['job']?.toString().toLowerCase().trim() == job.toLowerCase().trim()),
          orElse: () => null,
        );
        if (fallbackGroup != null && fallbackGroup['text'] is List) {
          questions = List<String>.from(fallbackGroup['text'].map((q) => q.toString()));
        }
      }

      // Final fallback: Default questions
      if (questions.isEmpty) {
        questions = [
          'Tell me about yourself',
          'Why are you interested in this position?',
          'Describe a challenging project you worked on',
          'What are your strengths?',
          'Where do you see yourself in 5 years?'
        ];
      }

      // Limit to 5 questions maximum
      questions = questions.take(5).toList();
      questions.shuffle();

      developer.log('Loaded ${questions.length} questions for: $job, $difficulty, $role');
      return questions;
    } catch (e) {
      developer.log('Error loading questions: $e');
      return [
        'Default question: Describe your relevant experience',
        'Default question: What skills make you a good candidate for this role?',
        'Default question: Tell me about yourself',
        'Default question: Why do you want this job?',
        'Default question: What are your career goals?'
      ].take(5).toList();
    }
  }
}