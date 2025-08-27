// lib/interviewProcessScreen.dart
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../../domain/services/aiService.dart';
import '../../../domain/services/question_service.dart';
import '../../../main.dart';
import 'answerRecorderScreen.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;

class InterviewQuestionScreen extends StatefulWidget {
  final String job;
  final String difficulty;
  final String role;

  const InterviewQuestionScreen({
    super.key,
    required this.job,
    required this.difficulty,
    required this.role,
  });

  @override
  State<InterviewQuestionScreen> createState() =>
      _InterviewQuestionScreenState();
}

class _InterviewQuestionScreenState extends State<InterviewQuestionScreen> {
  int _questionCount = 0;
  int _questionIndex = 0;
  int _maxQuestions = 5;
  String _currentQuestion = "";
  String _userAnswer = "";
  String _aiRating = "";
  String _correctAnswer = "";
  bool _showAnswer = false;
  bool _isInitialized = false;

  List<String> _questions = [];

  // AI evaluation state
  bool _isAiProcessing = false;
  List<double> _ratings = [];
  List<String> _mustKeywords = [];
  List<String> _grammarIssues = [];
  List<String> _highlights = [];
  String _advice = "";
  String _improvedAnswer = "";

  @override
  void initState() {
    super.initState();
    _maxQuestions = 5;
    _loadQuestions().then((_) {
      debugPrint('Loaded questions: $_questions'); // Add this line
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  void _showCompletionDialog() async {
    final questionsAnswered = _ratings.length;
    final questionWord = questionsAnswered == 1 ? 'question' : 'questions';

    final avgRating = _ratings.isNotEmpty
        ? (_ratings.reduce((a, b) => a + b) / _ratings.length)
        : 0.0;

    final contentText = "You have answered $questionsAnswered $questionWord!\n\nScore: ${avgRating.toStringAsFixed(1)}/10";

    await _updateInterviewCount();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Interview Complete"),
        content: Text(contentText),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () {
              Navigator.pop(context); // Close dialog first
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  Navigator.pop(context); // Then navigate back
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateInterviewCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('interviewsDone') ?? 0;
    final newCount = currentCount + 1;
    await prefs.setInt('interviewsDone', newCount);
    await prefs.setString('lastStatsUpdate', DateTime.now().toIso8601String());

    // ADD THIS LINE to trigger the stream update
    QuickStatsManager().updateStats(newCount, prefs.getInt('resumeScore') ?? 0);
  }

  Future<void> _loadQuestions() async {
    try {
      final qlist = await QuestionService.loadQuestions(
        widget.job,
        widget.difficulty,
        widget.role,
      );

      setState(() {
        _questions = qlist.take(_maxQuestions).toList();
        _currentQuestion = _questions.isNotEmpty
            ? _questions[0]
            : "No questions available";
        _resetAnswerState();
      });
    } catch (e) {
      debugPrint('Failed to load questions: $e');
      setState(() {
        _questions = [
          'Tell me about yourself',
          'Why are you interested in this position?',
          'Describe a challenging project',
          'What are your strengths?',
          'Where do you see yourself in 5 years?',
        ].take(_maxQuestions).toList();
        _currentQuestion = _questions.isNotEmpty
            ? _questions[0]
            : "No questions available";
      });
    }
  }



  void _loadNextQuestion() {
    if (_questionIndex + 1 >= _maxQuestions) {
      _showCompletionDialog();
      return;
    }

    setState(() {
      _questionIndex++;
      _currentQuestion = _questions[_questionIndex];
      _resetAnswerState();
    });
  }

  void _resetAnswerState() {
    setState(() {
      _userAnswer = "";
      _aiRating = "";
      _correctAnswer = "";
      _showAnswer = false;
      _isAiProcessing = false;
      _mustKeywords = [];
      _grammarIssues = [];
      _highlights = [];
      _advice = "";
      _improvedAnswer = "";
    });
  }

  Future<void> _recordAnswer() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const AnswerRecorderScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        _userAnswer = result;
        _isAiProcessing = true;
        _aiRating = "";
        _mustKeywords = [];
        _grammarIssues = [];
        _highlights = [];
        _advice = "";
        _improvedAnswer = "";
      });

      try {
        final feedback = await AIFeedbackService.getAIFeedback(
          question: _currentQuestion,
          answer: _userAnswer,
          job: widget.job,
          role: widget.role,
          difficulty: widget.difficulty,
          questionIndex: _questionCount,
        );

        setState(() {
          final ratingVal = feedback['rating'];
          if (ratingVal is num) {
            _aiRating = "${ratingVal.toString()}/10";
            _ratings.add((ratingVal as num).toDouble());
          } else {
            _aiRating = feedback['rating']?.toString() ?? '';
          }

          _mustKeywords =
              (feedback['must_keywords'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
                  [];
          _grammarIssues =
              (feedback['grammar_issues'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
                  [];
          _highlights =
              (feedback['highlights'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
                  [];
          _advice = (feedback['advice'] ?? "") as String;
          _improvedAnswer = (feedback['improved_answer'] ?? "") as String;
        });
      } catch (e) {
        debugPrint('AI evaluation failed: $e');
        setState(() {
          _advice = 'Failed to get AI feedback: $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isAiProcessing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 650;

    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Loading questions..."),
            ],
          ),
        ),
      );
    }

    if (isSmallScreen) {
      return Scaffold(
        appBar: AppBar(title: const Text('Interview')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            children: [
              // Question Section
              Text(
                "Question ${_questionIndex + 1}/$_maxQuestions",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _currentQuestion,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Answer Section
              if (_userAnswer.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Your Answer:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.lightBlue.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_userAnswer),
                ),
                const SizedBox(height: 12),
              ],

              // Record Button
              Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: _recordAnswer,
                    child: const Text(
                      "Record Answer",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // AI Feedback
              if (_aiRating.isNotEmpty || _isAiProcessing)
                Text(
                  "Score: $_aiRating",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 12),

              if (_isAiProcessing) ...[
                const Center(
                  child: SizedBox(
                    height: 48,
                    width: 48,
                    child: CircularProgressIndicator(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text("AI feedback is being evaluated..."),
                const SizedBox(height: 20),
              ],

              if (_aiRating.isNotEmpty) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.lightGreen[200],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Center( // Added Center widget here
                        child: Text(
                          "Suggestions",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.lightGreen[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 0),
                          if (_mustKeywords.isNotEmpty) ...[
                            const Text(
                              "Must keywords:",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(_mustKeywords.join(', ')),
                            const SizedBox(height: 8),
                          ],
                          if (_grammarIssues.isNotEmpty) ...[
                            const Text(
                              "Grammar issues:",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _grammarIssues
                                  .map((g) => Text("- $g"))
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_advice.isNotEmpty) ...[
                            const Text(
                              "Advice:",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(_advice),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              if (_improvedAnswer.isNotEmpty && !_isAiProcessing) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.lightGreen[200],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Center( // Added Center widget here
                        child: Text(
                          "Improved Answer",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                    Card(
                      elevation: 1,
                      color: Colors.lightGreen[50],
                      margin: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_improvedAnswer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Next Question Button
              if (_isInitialized)
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue[300],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _loadNextQuestion,
                    child: const Text(
                      "Next Question",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }

    // Original layout for larger screens
    return Scaffold(
      appBar: AppBar(title: const Text('Interview')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      "Question ${_questionIndex + 1}/$_maxQuestions",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currentQuestion,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),

                    if (_userAnswer.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Your Answer:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.lightBlue.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_userAnswer),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[400],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: _recordAnswer,
                          child: const Text(
                            "Record Answer",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_aiRating.isNotEmpty || _isAiProcessing)
                      Text(
                        "Score: $_aiRating",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  child: Column(
                    children: [
                      if (_isAiProcessing) ...[
                        const SizedBox(height: 8),
                        const Center(
                          child: SizedBox(
                            height: 48,
                            width: 48,
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text("AI feedback is being evaluated..."),
                        const SizedBox(height: 20),
                      ],

                      if (_aiRating.isNotEmpty) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.lightGreen[200],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: const Center( // Added Center widget here
                                child: Text(
                                  "Suggestions",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.lightGreen[50],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  if (_mustKeywords.isNotEmpty) ...[
                                    const Text(
                                      "Must keywords:",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(_mustKeywords.join(', ')),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_grammarIssues.isNotEmpty) ...[
                                    const Text(
                                      "Grammar issues:",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: _grammarIssues
                                          .map((g) => Text("- $g"))
                                          .toList(),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_advice.isNotEmpty) ...[
                                    const Text(
                                      "Advice:",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(_advice),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (_improvedAnswer.isNotEmpty && !_isAiProcessing) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.lightGreen[200],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: const Center( // Added Center widget here
                                child: Text(
                                  "Improved Answer",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ),
                            Card(
                              elevation: 1,
                              color: Colors.lightGreen[50],
                              margin: EdgeInsets.zero,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(_improvedAnswer),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isInitialized)
            Positioned(
              bottom: 20 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: Container(
                      width: constraints.maxWidth * 0.4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(31),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue[300],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _loadNextQuestion,
                        child: const Text(
                          "Next Question",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
