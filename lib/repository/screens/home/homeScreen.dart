import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
// import 'package:flutter/system.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../main.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware, WidgetsBindingObserver {
  String _username = "User";
  Map<String, dynamic> _currentQuote = {
    "text": "The best way to predict the future is to create it.",
    "author": "Abraham Lincoln"
  };
  List<dynamic> _quotes = [];
  DateTime? _lastRefreshTime;
  final Random _random = Random();

  // Quick Stats variables
  int _interviewsDone = 0;
  int _resumeScore = 0;
  DateTime? _lastStatsUpdateTime;

  // Timer for periodic refresh
  Timer? _refreshTimer;
  StreamSubscription<Map<String, int>>? _statsSubscription;

  // ===== Updated News variables (using NewsData.io API) =====
  List<dynamic> _allNews = [];
  bool _isLoadingNews = true;
  final String _newsApiKey = "pub_b0eda54b4845449f993466475e816dcb"; // Replace with your actual API key
  final ScrollController _pageScrollController = ScrollController();
  String? _nextPage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
    _loadQuickStats();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statsSubscription?.cancel();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    print('HomeScreen didPushNext - pausing refresh');
    _refreshTimer?.cancel();
  }

  @override
  void didPopNext() {
    print('HomeScreen didPopNext - resuming refresh and loading stats');
    _setupPeriodicRefresh();
    _loadQuickStats();
  }

  @override
  void initState() {
    super.initState();
    print('initState called');
    WidgetsBinding.instance.addObserver(this);

    _loadUsername();

    // Load quotes first, then load current quote
    print('Loading quotes...');
    _loadQuotes().then((_) {
      print('Quotes loaded, now loading current quote. Quotes count: ${_quotes.length}');
      _loadCurrentQuote(); // use the time-based logic
    }).catchError((error) {
      print('Error in quote loading chain: $error');
    });

    _loadQuickStats();
    _fetchNews(); // Fetch news from NewsData.io

    // Set up periodic refresh every 5 seconds when screen is visible
    _setupPeriodicRefresh();

    // Set up stream listener for immediate updates
    _setupStatsStreamListener();

    // Set up scroll listener for infinite scrolling
    _pageScrollController.addListener(_onPageScrollForNews);
  }

  void _onPageScrollForNews() {
    // Implement infinite scrolling if needed
    // For now, we'll keep it simple with pull-to-refresh
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _loadQuickStats();
    }
  }

  Future<void> _fetchNews({bool loadMore = false}) async {
    setState(() => _isLoadingNews = true);

    try {
      final url =
          "https://newsdata.io/api/1/news?apikey=$_newsApiKey&q=jobs,ai,technology&language=en${loadMore && _nextPage != null ? "&page=$_nextPage" : ""}";

      final response = await http.get(Uri.parse(url));

      debugPrint("Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data["status"] == "success") {
          setState(() {
            if (!loadMore) _allNews.clear();

            // Collect existing titles (to avoid repeats)
            final existingTitles =
            _allNews.map((n) => (n["title"] ?? "").trim()).toSet();

            // Keep only unique titles
            final newResults = (data["results"] ?? []).where((article) {
              final title = (article["title"] ?? "").trim();
              if (title.isEmpty) return false;
              if (existingTitles.contains(title)) return false;

              existingTitles.add(title);
              return true;
            }).toList();

            // Add only unique news
            _allNews.addAll(newResults);

            // Save next page token
            _nextPage = data["nextPage"];
          });
        } else {
          debugPrint("API Error: ${data["message"]}");
        }
      } else {
        debugPrint("Failed to fetch news: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching news: $e");
    } finally {
      setState(() => _isLoadingNews = false);
    }
  }

  void _setupPeriodicRefresh() {
    print('Setting up periodic refresh...');
    // Cancel any existing timer
    _refreshTimer?.cancel();

    // Set up new timer for periodic refresh every 5 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted) {
        print('Periodic refresh triggered at: ${DateTime.now().toIso8601String()}');
        _loadQuickStats();
      } else {
        print('Widget not mounted, stopping periodic refresh');
        timer.cancel();
      }
    });
  }

  void _setupStatsStreamListener() {
    // Listen for updates from the QuickStatsManager
    _statsSubscription = QuickStatsManager().statsStream.listen((stats) {
      if (mounted) {
        print('Received stats update via stream: $stats');
        setState(() {
          _interviewsDone = stats['interviews'] ?? 0;
          _resumeScore = stats['resumeScore'] ?? 0;
          _lastStatsUpdateTime = DateTime.now();
        });

        // Also update SharedPreferences for consistency
        _saveStatsToPrefs(_interviewsDone, _resumeScore);
      }
    });
  }

  Future<void> _saveStatsToPrefs(int interviews, int resumeScore) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('interviewsDone', interviews);
    await prefs.setInt('resumeScore', resumeScore);
    await prefs.setString('lastStatsUpdate', DateTime.now().toIso8601String());
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? "User";
    });
  }

  Future<void> _loadQuotes() async {
    try {
      print('Loading quotes from file...');
      final String response = await rootBundle.loadString('lib/data/quotes.json');
      final data = await json.decode(response);
      // Remove setState() - update the variable directly
      _quotes = data;
      print("Loaded ${_quotes.length} quotes"); // Add debug print
    } catch (e) {
      print("Error loading quotes: $e");
      // Add stack trace for better debugging
      print("Stack trace: ${StackTrace.current}");
    }
  }

  Future<void> _loadCurrentQuote() async {
    try {
      print('_loadCurrentQuote called');
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Check if we need to refresh the quote
      final lastRefresh = prefs.getString('lastQuoteRefresh');
      bool needsRefresh = true;

      if (lastRefresh != null) {
        final lastRefreshTime = DateTime.parse(lastRefresh);
        final difference = now.difference(lastRefreshTime);
        needsRefresh = difference.inMinutes >= 1;
        print('Last quote refresh: $lastRefreshTime');
        print('Time difference: ${difference.inMinutes} minutes');
        print('Needs refresh: $needsRefresh');
      } else {
        print('No last refresh time found, forcing refresh');
      }

      // Ensure quotes are loaded
      if (_quotes.isEmpty) {
        print('Quotes empty, loading them again...');
        await _loadQuotes();
        if (_quotes.isEmpty) {
          print('No quotes available after loading');
          return;
        }
      }

      if (needsRefresh) {
        // Refresh the quote
        final randomIndex = _random.nextInt(_quotes.length);
        final newQuote = _quotes[randomIndex];

        await prefs.setString('currentQuoteText', newQuote["text"]);
        await prefs.setString('currentQuoteAuthor', newQuote["author"]);
        await prefs.setString('lastQuoteRefresh', now.toIso8601String());

        setState(() {
          _currentQuote = newQuote;
          _lastRefreshTime = now;
        });
        print('Quote refreshed: ${newQuote["text"]}');
      } else {
        // Load saved quote
        final savedQuoteText = prefs.getString('currentQuoteText');
        final savedQuoteAuthor = prefs.getString('currentQuoteAuthor');

        if (savedQuoteText != null && savedQuoteAuthor != null) {
          setState(() {
            _currentQuote = {
              "text": savedQuoteText,
              "author": savedQuoteAuthor
            };
          });
          print('Loaded saved quote: $savedQuoteText');
        } else {
          // Fallback if no saved quote
          final randomIndex = _random.nextInt(_quotes.length);
          final newQuote = _quotes[randomIndex];

          await prefs.setString('currentQuoteText', newQuote["text"]);
          await prefs.setString('currentQuoteAuthor', newQuote["author"]);
          await prefs.setString('lastQuoteRefresh', now.toIso8601String());

          setState(() {
            _currentQuote = newQuote;
          });
          print('Fallback quote set: ${newQuote["text"]}');
        }
      }
    } catch (e) {
      print('Error in _loadCurrentQuote: $e');
      print("Stack trace: ${StackTrace.current}");
    }
  }

  Future<void> _loadLastRefreshTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRefresh = prefs.getString('lastQuoteRefresh');
    if (lastRefresh != null) {
      setState(() {
        _lastRefreshTime = DateTime.parse(lastRefresh);
      });
    }
  }

  Future<void> _loadQuickStats() async {
    try {
      print('=== Loading quick stats ===');
      final prefs = await SharedPreferences.getInstance();
      final savedStatsTime = prefs.getString('lastStatsUpdate');
      DateTime? statsTime;

      if (savedStatsTime != null) {
        statsTime = DateTime.parse(savedStatsTime);
      }

      final newInterviewsDone = prefs.getInt('interviewsDone') ?? 0;
      final newResumeScore = prefs.getInt('resumeScore') ?? 0;

      print('Current SharedPreferences - Interviews: $newInterviewsDone, Resume: $newResumeScore');
      print('Current UI State - Interviews: $_interviewsDone, Resume: $_resumeScore');

      // Always update the state, even if values are the same, to ensure UI reflects current data
      if (mounted) {
        setState(() {
          _interviewsDone = newInterviewsDone;
          _resumeScore = newResumeScore;
          _lastStatsUpdateTime = statsTime;
        });
        print('Quick stats updated: Interviews=$_interviewsDone, Resume=$_resumeScore');
      }
      print('=== End quick stats check ===');
    } catch (e) {
      print('Error loading quick stats: $e');
    }
  }

  String _formatStatsUpdateTime() {
    if (_lastStatsUpdateTime == null) return "Never";
    final now = DateTime.now();
    final difference = now.difference(_lastStatsUpdateTime!);
    if (difference.inDays > 0) {
      return "${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago";
    } else {
      return "Just now";
    }
  }

  String _formatLastUpdateTime() {
    if (_lastRefreshTime == null) return "Never";
    final now = DateTime.now();
    final difference = now.difference(_lastRefreshTime!);
    if (difference.inDays > 0) {
      return "${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago";
    } else {
      return "Just now";
    }
  }

  void _refreshQuote() async {
    if (_quotes.isEmpty) {
      await _loadQuotes();
      if (_quotes.isEmpty) return;
    }
    final randomIndex = _random.nextInt(_quotes.length);
    setState(() {
      _currentQuote = _quotes[randomIndex];
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentQuoteText', _currentQuote["text"]);
    await prefs.setString('currentQuoteAuthor', _currentQuote["author"]);
    final now = DateTime.now();
    await prefs.setString('lastQuoteRefresh', now.toIso8601String());
    setState(() {
      _lastRefreshTime = now;
    });
  }

  Future<void> _openArticle(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) debugPrint('Could not launch $uri');
    } catch (e) {
      debugPrint('Failed to launch $url: $e');
    }
  }

  // ===== Updated method: Build News Card =====
  // ===== Updated method: Build News Card with larger size =====
  // ===== Updated method: Build News Card with colored background =====
  Widget _buildNewsCard(dynamic article) {
    final title = article["title"] ?? "No Title";
    final source = article["source_id"] ?? "Unknown";
    final date = article["pubDate"] ?? "";
    final imageUrl = article["image_url"];
    final link = article["link"];
    final description = article["description"] ?? "";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      color: Colors.transparent, // Make card transparent to show container background
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.purple.shade50],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _openArticle(link),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null
                      ? Image.network(
                    imageUrl,
                    width: 100,
                    height: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 130,
                        color: Colors.white.withOpacity(0.8),
                        child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                      );
                    },
                  )
                      : Container(
                    width: 100,
                    height: 130,
                    color: Colors.white.withOpacity(0.8),
                    child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                  ),
                ),

                const SizedBox(width: 16),

                // Text content section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title and source
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                                color: Colors.black87,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 6),

                            Text(
                              source,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Date and time
                      Text(
                        _formatArticleDate(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
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
    );
  }

  // ===== Build Load More Button =====
  Widget _buildLoadMoreButton() {
    if (_nextPage == null) return SizedBox.shrink(); // no more pages
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () => _fetchNews(loadMore: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade300,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.blue.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 20),
              SizedBox(width: 8),
              Text(
                "Load More News",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.blue.shade600, Colors.purple.shade600],
            ).createShader(bounds);
          },
          child: Text(
            'Hello, $_username',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue.shade800),
        actions: [
          // IconButton(
          //   icon: Icon(Icons.refresh, color: Colors.blue.shade800),
          //   onPressed: () => _fetchNews(loadMore: false),
          //   tooltip: 'Refresh news',
          // ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchNews(loadMore: false),
        child: SingleChildScrollView(
          controller: _pageScrollController,
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Quote Box
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade50, Colors.purple.shade50],
                  ),
                  border: Border.all(
                    color: Colors.blue.shade100,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Positioned(
                          left: -10,
                          top: -15,
                          child: Text(
                            "“",
                            style: TextStyle(
                              fontSize: 64,
                              color: Colors.blue.shade200,
                              fontFamily: 'Times New Roman',
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 20, right: 8, top: 8, bottom: 4),
                          child: Text(
                            _currentQuote["text"],
                            style: const TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Text(
                            "- ${_currentQuote["author"]}",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.autorenew, color: Colors.blue.shade600),
                          onPressed: _refreshQuote,
                          tooltip: 'Refresh quote',
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Stats Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quick Stats',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          'Updated: ${_formatStatsUpdateTime()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.blue.shade100, Colors.blue.shade300],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.people_alt_outlined,
                                        color: Colors.blue.shade700,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Interviews',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$_interviewsDone',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                        height: 0.9,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        'Completed',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: _interviewsDone / 20,
                                  backgroundColor: Colors.blue.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.purple.shade100, Colors.purple.shade300],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.star_border_outlined,
                                        color: Colors.purple.shade700,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Resume Score',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$_resumeScore',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple.shade900,
                                        height: 0.9,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        'Out of 100',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: _resumeScore / 100,
                                  backgroundColor: Colors.purple.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),

              // ===== News Section =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Latest News',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        // IconButton(
                        //   icon: Icon(Icons.refresh, color: Colors.blue.shade600),
                        //   tooltip: 'Refresh News',
                        //   onPressed: () => _fetchNews(loadMore: false),
                        // ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _isLoadingNews && _allNews.isEmpty
                        ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                        : _allNews.isEmpty
                        ? Container(
                      padding: const EdgeInsets.all(24),
                      child: const Center(
                        child: Text(
                          "No news found. Please refresh.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                        : Column(
                      children: [
                        ...List.generate(
                          _allNews.length,
                              (index) => _buildNewsCard(_allNews[index]),
                        ),
                        _buildLoadMoreButton(),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // Add floating action button to scroll to top
      floatingActionButton: Container(
        width: 50,  // Smaller button size
        height: 50, // Smaller button size
        child: FloatingActionButton(
          onPressed: () {
            _pageScrollController.animateTo(
              0,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          },
          child: Icon(Icons.arrow_upward, size: 28), // Larger arrow size
          backgroundColor: Colors.white,
          foregroundColor: Colors.purple.shade200,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  String _formatArticleDate(String dateString) {
    if (dateString.isEmpty) return "";

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return "${difference.inDays}d ago";
      } else if (difference.inHours > 0) {
        return "${difference.inHours}h ago";
      } else if (difference.inMinutes > 0) {
        return "${difference.inMinutes}m ago";
      } else {
        return "Just now";
      }
    } catch (e) {
      return dateString;
    }
  }
}