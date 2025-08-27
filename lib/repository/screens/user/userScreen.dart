import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../domain/services/apiKeyService.dart';
import 'dart:async';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _apiKeyController = TextEditingController();
  bool _isKeySaved = false;
  String? _savedApiKey;

  @override
  void initState() {
    super.initState();
    _loadSavedApiKey();
  }

  Future<void> _loadSavedApiKey() async {
    final apiKey = await ApiKeyService.getApiKey();
    setState(() {
      _savedApiKey = apiKey;
      _isKeySaved =
          apiKey != null &&
          apiKey.length >= 10; // Only consider valid if >= 10 chars
    });
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();

    // ✅ Check if too short or invalid
    if (key.length < 10) {
      _showCupertinoAlert(
        'Invalid Key',
        'The API key you entered is too short (${key.length} characters).\nPlease enter a valid key with at least 10 characters.',
      );
      return;
    }

    // ✅ Additional validation - check if it looks like an API key
    if (!key.startsWith('sk-')) {
      _showCupertinoAlert(
        'Invalid Format',
        'OpenRouter API keys usually start with "sk-". Please check your key.',
      );
      return;
    }

    // ✅ Store the navigator to dismiss the dialog later
    NavigatorState? navigator;

    // ✅ Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        navigator = Navigator.of(context); // Capture the navigator
        return const CupertinoAlertDialog(
          title: Text('Validating API Key'),
          content: Padding(
            padding: EdgeInsets.only(top: 16),
            child: CupertinoActivityIndicator(),
          ),
        );
      },
    );

    try {
      // ✅ Validate the API key by making a test request
      final isValid = await _validateApiKey(key);

      // ✅ Dismiss loading indicator only after validation completes
      if (navigator != null && navigator!.canPop()) {
        navigator!.pop();
      }

      if (isValid) {
        // ✅ Save the key if valid
        await ApiKeyService.saveApiKey(key);
        setState(() {
          _isKeySaved = true;
          _savedApiKey = key;
        });

        _apiKeyController.clear();
        FocusScope.of(context).unfocus();

        // ✅ Success popup
        _showCupertinoAlert(
          'Key Saved',
          'API key validated and stored securely',
        );
      } else {
        _showCupertinoAlert(
          'Invalid API Key',
          'The API key you entered appears to be invalid or not working.\nPlease check your key and try again.',
        );
      }
    } catch (e) {
      // ✅ Dismiss loading indicator on error
      if (navigator != null && navigator!.canPop()) {
        navigator!.pop();
      }
      _showCupertinoAlert(
        'Validation Error',
        'Failed to validate API key: ${e.toString()}',
      );
    }
  }

  // ✅ Add this new method to validate the API key
  Future<bool> _validateApiKey(String apiKey) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer': 'https://yourdomain.com',
              'X-Title': 'Interview Prep App',
            },
            body: jsonEncode({
              'model': 'deepseek/deepseek-r1:free',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a helpful assistant. Respond with "Hello" only.',
                },
                {'role': 'user', 'content': 'Say hello'},
              ],
              'max_tokens': 5,
              'temperature': 0.0,
            }),
          )
          .timeout(const Duration(seconds: 10));

      // Check if the API key is valid (status 200/201) or unauthorized (401)
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 401) {
        return false;
      } else {
        // For other status codes, we'll consider it invalid
        return false;
      }
    } on http.ClientException {
      return false; // Network error
    } on TimeoutException {
      return false; // Timeout
    } catch (e) {
      return false; // Any other error
    }
  }

  Future<void> _deleteApiKey() async {
    await ApiKeyService.deleteApiKey();
    setState(() {
      _isKeySaved = false;
      _savedApiKey = null;
      _apiKeyController.clear();
    });
    _showCupertinoAlert('Key Removed', 'API key deleted from device');
  }

  Future<void> _launchOpenAIURL() async {
    const url = 'https://openrouter.ai/keys';
    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);

          if (!launched) {
            throw Exception('Could not launch URL');
          }
        }
        return;
      }
      throw Exception('Could not launch URL');
    } catch (e) {
      debugPrint('Error launching URL: $e');
      await Clipboard.setData(const ClipboardData(text: url));
      _showCupertinoAlert(
        'Link Copied',
        'Could not open browser. URL copied to clipboard.',
      );
    }
  }

  void _showCupertinoAlert(String title, String message) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('API Settings')),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isKeySaved) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current API Key',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _savedApiKey!.length > 4
                            ? '••••••••${_savedApiKey!.substring(_savedApiKey!.length - 4)}'
                            : '••••••••', // Fallback for very short keys
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Text(
                              'Copy',
                              style: TextStyle(color: CupertinoColors.link),
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _savedApiKey!),
                              );
                              _showCupertinoAlert(
                                'Copied',
                                'API key copied to clipboard',
                              );
                            },
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                color: CupertinoColors.destructiveRed,
                              ),
                            ),
                            onPressed: _deleteApiKey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const Text(
                'Enter New API Key',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _apiKeyController,
                placeholder: 'sk-...',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(8),
                ),
                obscureText: true,
                obscuringCharacter: '•',
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    100,
                  ), // Reasonable max length
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  color: Colors.lightBlue[300], // Change this to black
                  borderRadius: BorderRadius.circular(30),
                  child: const Text('Save Key'),
                  onPressed: _saveApiKey,
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(top: 32, bottom: 12),
                child: Text(
                  'How to get your API key',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              _buildStep(1, 'Visit:'),
              GestureDetector(
                onTap: _launchOpenAIURL,
                child: const Padding(
                  padding: EdgeInsets.only(left: 24, bottom: 8),
                  child: Text(
                    'openrouter.ai/keys',
                    style: TextStyle(
                      color: CupertinoColors.link,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              _buildStep(2, 'Sign in with your Google account'),
              _buildStep(3, 'Click "Create new secret key"'),
              _buildStep(4, 'Enter any name and press Create'),
              _buildStep(5, 'Copy the generated API key'),
              _buildStep(6, 'Paste it above and click "Save Key"'),

              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Your API key is stored securely on this device only.',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}
