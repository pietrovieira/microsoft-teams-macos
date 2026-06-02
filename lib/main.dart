import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TeamsApp());
}

class TeamsApp extends StatelessWidget {
  const TeamsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microsoft Teams - Unofficial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TeamsHomePage(),
    );
  }
}

class TeamsHomePage extends StatefulWidget {
  const TeamsHomePage({super.key});

  @override
  State<TeamsHomePage> createState() => _TeamsHomePageState();
}

class _TeamsHomePageState extends State<TeamsHomePage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/125.0.0.0 Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            setState(() => _isLoading = false);
            _injectNotificationHandler();
          },
          onProgress: (progress) {
            setState(() => _progress = progress / 100.0);
          },
          onWebResourceError: (error) {
            debugPrint('Page load error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://teams.cloud.microsoft/'));
  }

  Future<void> _injectNotificationHandler() async {
    await _controller.runJavaScript('''
      (function() {
        if (typeof Notification !== 'undefined' && Notification.permission === 'default') {
          Notification.requestPermission();
        }
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(value: _progress),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
