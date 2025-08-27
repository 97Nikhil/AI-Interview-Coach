import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:flutter/services.dart';

class AnswerRecorderScreen extends StatefulWidget {
  const AnswerRecorderScreen({super.key});

  @override
  State<AnswerRecorderScreen> createState() => _AnswerRecorderScreenState();
}

class _AnswerRecorderScreenState extends State<AnswerRecorderScreen> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  String _wordsSpoken = "";
  bool _isListening = false;
  DateTime? _lastSpeechTime;
  Timer? _inactivityTimer;
  bool _showTimeoutWarning = false;
  double _confidenceLevel = 0.0;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _conversationHistory = [];
  int _currentSegment = 1;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _stopListening();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' && _isListening) {
            _restartListening();
          }
          setState(() {});
        },
        onError: (error) {
          if (error.errorMsg == 'error_no_match' && _isListening) {
            _restartListening();
          }
        },
      );
    } catch (e) {
      _showError('Initialization error: $e');
    }
    setState(() {});
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lastSpeechTime != null &&
          DateTime.now().difference(_lastSpeechTime!) >
              const Duration(seconds: 5)) {
        setState(() => _showTimeoutWarning = true);
      } else {
        setState(() => _showTimeoutWarning = false);
      }
    });
  }

  Future<void> _restartListening() async {
    await _stopListening();
    if (_isListening) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _startListening();
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechEnabled) return;
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    try {
      setState(() {
        _isListening = true;
        _showTimeoutWarning = false;
      });
      _startInactivityTimer();
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _wordsSpoken = result.recognizedWords;
            _confidenceLevel = result.confidence;
            _lastSpeechTime = DateTime.now();
            _showTimeoutWarning = false;
          });
          _scrollToBottom();
        },
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(minutes: 5),
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      );
    } catch (e) {
      if (_isListening) {
        _restartListening();
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
    } finally {
      _inactivityTimer?.cancel();
      if (mounted) {
        setState(() {
          _isListening = false;
          _showTimeoutWarning = false;
        });
      }
    }
  }

  Future<void> _startFreshListening() async {
    await _stopListening();
    setState(() {
      _conversationHistory.clear();
      _wordsSpoken = "";
      _currentSegment = 1;
    });
    await _startListening();
  }

  void _commitCurrentSegment() {
    if (_wordsSpoken.trim().isEmpty) return;
    _conversationHistory.add({
      'text': _wordsSpoken.trim(),
      'confidence': _confidenceLevel,
    });
    _currentSegment++;
    _wordsSpoken = "";
  }

  void _submitText() {
    if (_conversationHistory.isNotEmpty || _wordsSpoken.isNotEmpty) {
      setState(() {
        if (_wordsSpoken.isNotEmpty) {
          _commitCurrentSegment();
        }
      });

      String combinedText = _conversationHistory
          .map((segment) => segment['text'] as String)
          .join("\n");
      // _copyToClipboard(combinedText);

      if (_isListening) _stopListening();

      Navigator.of(context).pop(combinedText);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record some text first')),
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    // ScaffoldMessenger.of(
    //   context,
    // ).showSnackBar(const SnackBar(content: Text('Answer copied to clipboard')));
  }

  Future<void> _continueSpeaking() async {
    if (_wordsSpoken.isNotEmpty) {
      setState(() {
        _commitCurrentSegment();
      });
    }
    if (_isListening) {
      await _stopListening();
      await _startListening();
    } else {
      await _startListening();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Your Answer'),
        backgroundColor: Colors.lightBlue[300],
        foregroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      children: [
                        if (_conversationHistory.isNotEmpty)
                          ..._conversationHistory
                              .map(
                                (segment) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 4,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 3,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Confidence: ${((segment['confidence'] as double) * 100).toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blueGrey[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          segment['text'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black87,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Container(
                            constraints: BoxConstraints(
                              minHeight: 60,
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.4,
                            ),
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 5,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_wordsSpoken.isNotEmpty)
                                  Text(
                                    'Confidence: ${(_confidenceLevel * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blueGrey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  _wordsSpoken.isEmpty
                                      ? _isListening
                                            ? "Listening... (speak now)"
                                            : "Tap the mic to begin speaking"
                                      : _wordsSpoken,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitText,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue[300],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Submit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _continueSpeaking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightGreen[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      onPressed: _toggleListening,
                      backgroundColor: _isListening ? Colors.green[400] : Colors.red[400],
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_showTimeoutWarning)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Are you still there?",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      backgroundColor: Colors.white,
    );
  }
}
