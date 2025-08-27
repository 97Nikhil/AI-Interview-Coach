import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'interviewProcessScreen.dart';
import '../../../domain/services/apiKeyService.dart';

class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key});

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  String? _selectedJob;
  String? _selectedDifficulty;
  String? _selectedRole;
  bool _hasApiKey = false;

  final Map<String, List<String>> _jobRoles = {
    'Software Engineer': ['Technical', 'System Design', 'Behavioral'],
    'Data Scientist': [
      'MLOps/ML Platform Engineer',
      'Statistics',
      'Junior/Associate Data Scientist',
      'Computer Vision Engineer',
    ],
    'Product Manager': [
      'Product Sense',
      'Behavioral',
      'Estimation',
      'Execution',
    ],
    'UX Designer': [
      'Design Principles',
      'Tools',
      'Behavioral',
      'Design Challenge',
    ],
    'Frontend Developer': [
      'Core Web Fundamentals',
      'System Design',
      'Frameworks & Libraries',
      'Responsive Design & Cross-Browser Compatibility',
      'Testing & Debugging',
      'Web Security',
      'APIs & Data Handling',
      'Real-Time & Advanced Features',
    ],
    'Backend Developer': [
      'Technical',
      'System Design',
      'Behavioral',
      'Databases & Storage',
      'APIs & Integration',
      'Performance & Scalability',
      'Security',
      'DevOps & Deployment',
    ],
    'Mobile App Developer': ['Technical', 'System Design', 'Behavioral'],
    'AI/ML Engineer': [
      'Technical',
      'Statistics',
      'Behavioral',
      'System Design',
    ],
    'Python Developer': [
      'Data Processing',
      'Web Development',
      'Language Fundamentals',
      'Testing & Debugging',
      'Concurrency & Asynchronous Programming',
      'System Design (Python Focused)',
    ],
    'Java Developer': [
      'Core Java',
      'Spring Framework',
      'Database',
      'System Design',
      'Concurrency & Multithreading',
      'JVM Internals & Performance',
      'Testing & Debugging',
      'Security',
      'Build & Deployment Tools',
    ],
  };

  List<String> _availableRoles = [];

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkApiKey(); // Refresh when returning from settings
  }

  Future<void> _checkApiKey() async {
    final apiKey = await ApiKeyService.getApiKey();
    setState(() {
      _hasApiKey = apiKey != null && apiKey.isNotEmpty;
    });
  }

  void _startInterview(BuildContext context) async {
    if (_selectedJob == null ||
        _selectedDifficulty == null ||
        _selectedRole == null)
      return;

    // Double-check API key in real-time for reliability
    final apiKey = await ApiKeyService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _showApiKeyWarning();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InterviewQuestionScreen(
          job: _selectedJob!,
          difficulty: _selectedDifficulty!,
          role: _selectedRole!,
        ),
      ),
    );
  }

  void _showApiKeyWarning() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('API Key Required'),
        content: const Text(
          'Please set up your API key in the User Settings before starting an interview.',
        ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Interview Configuration',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),

              // Job Dropdown with improved styling
              _buildDropdown(
                value: _selectedJob,
                hint: 'Select Job',
                items: _jobRoles.keys.toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedJob = value;
                    _selectedRole = null;
                    _availableRoles = _jobRoles[value] ?? [];
                  });
                },
              ),
              const SizedBox(height: 25),

              const Text(
                'Select Difficulty Level:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: ['Beginner', 'Intermediate', 'Experienced']
                    .map(
                      (level) => ChoiceChip(
                        label: Text(
                          level,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _selectedDifficulty == level
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        selected: _selectedDifficulty == level,
                        selectedColor: Colors.blue.shade400,
                        backgroundColor: Colors.white,
                        elevation: 2,
                        pressElevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                          side: BorderSide(
                            color: _selectedDifficulty == level
                                ? Colors.blue.shade500
                                : Colors.grey.shade400,
                            width: 1.2,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedDifficulty = selected ? level : null;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),

              if (_selectedJob != null) ...[
                // Role Dropdown with improved styling
                _buildDropdown(
                  value: _selectedRole,
                  hint: 'Select Role/Position',
                  items: _availableRoles,
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                    });
                  },
                ),
                const SizedBox(height: 30),
              ],

              if (_selectedJob != null &&
                  _selectedDifficulty != null &&
                  _selectedRole != null)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.blue[300],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Interview Summary',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Position: $_selectedJob',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Level: $_selectedDifficulty',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Role: $_selectedRole',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'The interview will include questions tailored to your selected criteria.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed:
                      (_selectedJob != null &&
                          _selectedDifficulty != null &&
                          _selectedRole != null)
                      ? () => _startInterview(context)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Start Interview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.white,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
      ),
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }
}
