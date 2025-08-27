import 'dart:convert';
import 'dart:math';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:AIC/repository/screens/resume/resumeFeedbackScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../../../domain/services/aiService.dart';

class ResumeScreen extends StatefulWidget {
  const ResumeScreen({super.key});

  @override
  State<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends State<ResumeScreen> {
  PlatformFile? _selectedFile;
  String _fileName = "No file selected";
  bool _isHovering = false;
  bool _isLoading = false;
  String? _selectedJob;
  final List<String> _availableJobs = [
    'Software Engineer',
    'Senior Software Engineer',
    'Frontend Developer',
    'Backend Developer',
    'Python Developer',
    'Java Developer',
    'Javascript Developer',
    'C++ Developer',
    'Flutter Developer',
    'Full Stack Developer',
    'Mobile App Developer',
    'iOS Developer',
    'Android Developer',
    'DevOps Engineer',
    'Cloud Engineer',
    'Data Scientist',
    'Machine Learning Engineer',
    'AI Engineer',
    'Data Engineer',
    'Data Analyst',
    'Business Analyst',
    'Product Manager',
    'Technical Product Manager',
    'Product Owner',
    'Project Manager',
    'Scrum Master',
    'UX Designer',
    'UI Designer',
    'Graphic Designer',
    'React Developer',
    'UX Researcher',
    'Content Designer',
    'Marketing Specialist',
    'Digital Marketing Manager',
    'SEO Specialist',
    'Social Media Manager',
    'Content Marketing Manager',
    'Financial Analyst',
    'Investment Analyst',
    'Accountant',
    'Financial Controller',
    'HR Manager',
    'Recruiter',
    'Talent Acquisition Specialist',
    'Sales Executive',
    'Account Executive',
    'Business Development Manager',
    'Customer Success Manager',
    'Technical Writer',
    'Quality Assurance Engineer',
    'Test Automation Engineer',
    'Security Engineer',
    'Network Engineer',
    'Systems Administrator',
    'IT Support Specialist',
    'Solutions Architect',
    'Enterprise Architect',
    'CTO',
    'CEO',
    'COO',
    'CFO',
    'CMO',
    'CIO',
    'Research Scientist',
    'Academic Researcher',
    'Professor',
    'Teacher',
    'other'
  ];

  Future<void> _pickFile() async {
    try {
      setState(() => _isLoading = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.first;

      // Validate file first
      if (file.size == null || file.name.isEmpty || file.path == null) {
        throw Exception("Invalid file selected");
      }

      if (file.extension?.toLowerCase() != 'pdf') {
        setState(() => _isLoading = false);
        _showCupertinoAlert('Unsupported Format', 'Please upload a PDF file');
        return;
      }

      if (file.size! > 8 * 1024 * 1024) {
        setState(() => _isLoading = false);
        _showCupertinoAlert('File Too Large', 'File size exceeds 6MB limit');
        return;
      }

      // Try text extraction
      try {
        String pdfText = await ReadPdfText.getPDFtext(file.path!);
        debugPrint('------ PDF TEXT EXTRACTED (${pdfText.length} chars) ------');
        debugPrint(pdfText.substring(0, min(200, pdfText.length))); // Show first 200 chars
        debugPrint('----------------------------------------');

        setState(() {
          _selectedFile = file;
          _fileName = file.name;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        _showCupertinoAlert(
          'PDF Read Error',
          'Could not extract text. Ensure the PDF contains selectable text.',
        );
        debugPrint('PDF read error: ${e.toString()}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showCupertinoAlert('Error', 'Failed to process file: ${e.toString()}');
      debugPrint('File picker error: $e');
    }
  }

  // In the _handleAtsRating method, update the AI result handling:
  void _handleAtsRating() async {
    if (_selectedFile == null || _selectedJob == null) return;

    setState(() => _isLoading = true);
    try {
      // 1. Extract PDF text
      String pdfText = await AIFeedbackService.extractPdfText(_selectedFile!.path!);

      // 2. Call AI method
      final aiResult = await AIFeedbackService.analyzeResume(
        resumeText: pdfText,
        targetJob: _selectedJob!,
      );
      debugPrint('AI Analysis Result: $aiResult');

      // 3. Extract the JSON content from the response
      Map<String, dynamic> parsedResult = {};
      if (aiResult['choices'] != null && aiResult['choices'].isNotEmpty) {
        final content = aiResult['choices'][0]['message']['content'] as String;
        final jsonStart = content.indexOf('{');
        final jsonEnd = content.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final jsonString = content.substring(jsonStart, jsonEnd + 1);
          parsedResult = jsonDecode(jsonString) as Map<String, dynamic>;
        }
      }

      debugPrint('Parsed Result: $parsedResult');

      // 4. Navigate with parsed data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResumeFeedbackScreen(
            resumeFile: _selectedFile!,
            targetJob: _selectedJob!,
            analysisResult: parsedResult,
          ),
        ),
      );
    } catch (e) {
      _showCupertinoAlert('Error', 'Analysis failed: ${e.toString()}');
      debugPrint('Error in resume analysis: $e');
    } finally {
      setState(() => _isLoading = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 0), // Reduced from centered layout
              Text(
                "Make your Resume ATS ready.",
                style: TextStyle(fontSize: 22, color: Colors.blueGrey),
              ),
              const SizedBox(height: 20), // Spacing between text and upload box
              MouseRegion(
                onEnter: (_) => setState(() => _isHovering = true),
                onExit: (_) => setState(() => _isHovering = false),
                child: GestureDetector(
                  onTap: _isLoading ? null : _pickFile,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 500,
                    constraints: const BoxConstraints(maxWidth: 600),
                    decoration: BoxDecoration(
                      color: _selectedFile != null
                          ? Colors.lightGreen[50]
                          : Colors.lightBlue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedFile != null
                            ? Colors.green
                            : _isHovering
                            ? Colors.blue
                            : Colors.lightBlue[300]!,
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
                            color: _selectedFile != null
                                ? Colors.green[100]
                                : Colors.lightBlue[100],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isLoading
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : Icon(
                                _selectedFile != null
                                    ? Icons.check_circle
                                    : Icons.cloud_upload,
                                color: _selectedFile != null
                                    ? Colors.green
                                    : Colors.lightBlue[800],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isLoading
                                    ? "Processing..."
                                    : _selectedFile != null
                                    ? "Document Ready"
                                    : "Upload Your Resume",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedFile != null
                                      ? Colors.green
                                      : Colors.lightBlue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 0,
                            top: 20,
                            bottom: 20,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 55,
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildFeatureRow(
                                      "File Size: 6mb or Less",
                                    ),
                                    const SizedBox(height: 5),
                                    _buildFeatureRow(
                                      "Supports PDF only.",
                                    ),
                                    const SizedBox(height: 5),
                                    _buildFeatureRow("True Rating"),
                                    const SizedBox(height: 10),
                                    Text(
                                      _selectedFile != null
                                          ? path.basename(_fileName)
                                          : "No file selected",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _selectedFile != null
                                            ? Colors.green[800]
                                            : Colors.lightBlue[700],
                                        fontStyle: FontStyle.normal,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 45,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 25),
                                    child: _isLoading
                                        ? const SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(),
                                    )
                                        : _selectedFile != null
                                        ? const Icon(
                                      Icons.file_present,
                                      color: Colors.green,
                                      size: 60,
                                    )
                                        : Image.asset(
                                      'assets/images/doc_upload.png',
                                      width: 120,
                                      height: 120,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Job Selection Dropdown
              if (_selectedFile != null) ...[
                Container(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _selectedJob,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _selectedJob != null ? Colors.green[300]! : Colors.blue[300]!,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _selectedJob != null ? Colors.green[300]! : Colors.blue[300]!,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _selectedJob != null ? Colors.green[500]! : Colors.blue[500]!,
                          width: 2.0,
                        ),
                      ),
                      filled: true,
                      fillColor: _selectedJob != null ? Colors.green[50] : Colors.blue[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    hint: const Text('Select a job role'),
                    items: _availableJobs.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedJob = newValue;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a job';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 40),
              ],

              // ATS Rating Button
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: _selectedFile == null || _isLoading
                      ? null
                      : _handleAtsRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedJob != null
                        ? Colors.blue
                        : Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(34),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    "Analyze Resume",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset('assets/images/star.png', width: 20, height: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}