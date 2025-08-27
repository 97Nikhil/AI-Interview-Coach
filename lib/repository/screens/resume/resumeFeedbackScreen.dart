import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart';

class ResumeFeedbackScreen extends StatefulWidget {
  final PlatformFile resumeFile;
  final String targetJob;
  final Map<String, dynamic> analysisResult;

  const ResumeFeedbackScreen({
    super.key,
    required this.resumeFile,
    required this.targetJob,
    required this.analysisResult,
  });

  @override
  State<ResumeFeedbackScreen> createState() => _ResumeFeedbackScreenState();
}

class _ResumeFeedbackScreenState extends State<ResumeFeedbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateResumeScore();
    });
  }

  Future<void> _updateResumeScore() async {
    final score = (widget.analysisResult['score'] as num?)?.toInt() ?? 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('resumeScore', score);
    await prefs.setString('lastStatsUpdate', DateTime.now().toIso8601String());

    // ADD THIS LINE to trigger the stream update
    QuickStatsManager().updateStats(prefs.getInt('interviewsDone') ?? 0, score);
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green.shade700;
    if (score >= 60) return Colors.orange.shade700;
    return Colors.red.shade700;
  }


  @override
  Widget build(BuildContext context) {
    // Safely extract data with proper type casting
    final score = (widget.analysisResult['score'] as num?)?.toInt() ?? 0;
    final grammarIssues = (widget.analysisResult['grammar_issues'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final formattingIssues = (widget.analysisResult['formatting_issues'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final missingKeywords = (widget.analysisResult['missing_keywords'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final overallFeedback = widget.analysisResult['overall_feedback'] as String? ?? 'No feedback available';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resumeFile.name),
        backgroundColor: Colors.lightBlue[100],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Minimal target job display
            if (widget.targetJob.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Analyzed for: ${widget.targetJob}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // ATS Score Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.lightBlue[100]!,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assessment, color: Colors.lightBlue[800]),
                        const SizedBox(width: 8),
                        Text(
                          "ATS Score",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.lightBlue[800], // Matches icon color
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      score.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(score),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ... rest of your build method remains the same, just change analysisResult to widget.analysisResult
            // Grammar Issues Box - Red Theme
            if (grammarIssues.isNotEmpty)
              _buildFeedbackBox(
                title: 'Grammar Issues',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var issue in grammarIssues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ${issue['mistake'] ?? ''}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700], // Red for problems
                              ),
                            ),
                            if (issue['suggestion'] != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text(
                                  '→ ${issue['suggestion']}',
                                  style: TextStyle(
                                    color: Colors.green[700], // Green for solutions
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                icon: Icons.grade,
                headerColor: Colors.red[50]!,
                borderColor: Colors.red[100]!,
                iconColor: Colors.red[700]!,
                titleTextColor: Colors.red[700]!, // Matches border
              ),

            if (grammarIssues.isNotEmpty) const SizedBox(height: 16),

            // Formatting Issues Box - Orange Theme
            if (formattingIssues.isNotEmpty)
              _buildFeedbackBox(
                title: 'Formatting Issues',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var issue in formattingIssues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ${issue['issue'] ?? ''}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700], // Orange for problems
                              ),
                            ),
                            if (issue['suggestion'] != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text(
                                  '→ ${issue['suggestion']}',
                                  style: TextStyle(
                                    color: Colors.green[700], // Green for solutions
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                icon: Icons.format_align_left,
                headerColor: Colors.orange[50]!,
                borderColor: Colors.orange[100]!,
                iconColor: Colors.orange[700]!,
                titleTextColor: Colors.orange[700]!, // Matches border
              ),

            if (formattingIssues.isNotEmpty) const SizedBox(height: 16),

            // Missing Keywords Box - Purple Theme
            if (missingKeywords.isNotEmpty)
              _buildFeedbackBox(
                title: 'Missing Keywords',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var keyword in missingKeywords)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ${keyword['keyword'] ?? ''}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[700], // Purple for problems
                              ),
                            ),
                            if (keyword['why_important'] != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text(
                                  '${keyword['why_important']}',
                                  style: TextStyle(
                                    color: Colors.green[700], // Green for solutions
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                icon: Icons.key,
                headerColor: Colors.purple[50]!,
                borderColor: Colors.purple[100]!,
                iconColor: Colors.purple[700]!,
                titleTextColor: Colors.purple[700]!, // Matches border
              ),

            if (missingKeywords.isNotEmpty) const SizedBox(height: 16),

            // Overall Feedback Box - Green Theme
            _buildFeedbackBox(
              title: 'Overall Feedback',
              content: Text(
                overallFeedback,
                style: TextStyle(
                  color: Colors.grey[800], // Dark grey for readability
                  height: 1.4, // Better line spacing
                ),
              ),
              icon: Icons.lightbulb,
              headerColor: Colors.green[50]!,
              borderColor: Colors.green[100]!,
              iconColor: Colors.green[700]!,
              titleTextColor: Colors.green[700]!, // Matches border
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackBox({
    required String title,
    required Widget content,
    required IconData icon,
    required Color headerColor,
    required Color borderColor,
    required Color iconColor,
    required Color titleTextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleTextColor, // Uses the border color
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ],
      ),
    );
  }
}