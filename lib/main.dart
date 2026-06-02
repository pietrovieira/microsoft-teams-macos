import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _TeamsHomePageState extends State<TeamsHomePage>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  late final MethodChannel _platformChannel;
  Timer? _keepAliveTimer;
  Timer? _reloadTimer;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _setupPlatformChannel();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/125.0.0.0 Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('Page started: $url');
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            debugPrint('Page finished: $url');
            setState(() => _isLoading = false);
            _onPageLoaded();
          },
          onProgress: (progress) {
            setState(() => _progress = progress / 100.0);
          },
          onNavigationRequest: (request) {
            debugPrint('Navigation request: ${request.url}');
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint('Page load error: ${error.description} (code: ${error.errorCode})');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://teams.cloud.microsoft/'));
  }

  void _setupPlatformChannel() {
    _platformChannel = const MethodChannel('com.teams.app/settings');
    _platformChannel.invokeMethod('preventSleep');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAliveTimer?.cancel();
    _reloadTimer?.cancel();
    _platformChannel.invokeMethod('allowSleep');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startKeepAlive();
      _controller.loadRequest(Uri.parse('https://teams.cloud.microsoft/'));
    } else {
      _keepAliveTimer?.cancel();
    }
  }

  void _onPageLoaded() {
    _injectNotificationHandler();
    _injectPopupHandler();
    _requestMediaAccess();
    _startKeepAlive();
    _cancelReload();
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

  Future<void> _injectPopupHandler() async {
    await _controller.runJavaScript('''
      (function() {
        if (!window.__popupHandlerInjected) {
          window.__popupHandlerInjected = true;
          var _originalOpen = window.open;
          window.open = function(url, name, features) {
            if (url) {
              window.location.href = url;
            }
            return { closed: false, close: function() {} };
          };
        }
      })();
    ''');
  }

  Future<void> _requestMediaAccess() async {
    const js = '''
      (function() {
        try {
          navigator.mediaDevices.getUserMedia({ audio: true, video: true })
            .then(function(stream) {
              stream.getTracks().forEach(function(track) { track.stop(); });
              return true;
            })
            .catch(function(e) {
              console.error('Media permission denied:', e);
              return false;
            });
        } catch(e) {
          console.error('Media request error:', e);
        }
      })();
    ''';
    await _controller.runJavaScript(js);
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _injectActivity(),
    );
  }

  Future<void> _injectActivity() async {
    await _controller.runJavaScript('''
      (function() {
        document.dispatchEvent(new MouseEvent('mousemove', {
          view: window,
          bubbles: true,
          cancelable: true,
          clientX: Math.random() * window.innerWidth,
          clientY: Math.random() * window.innerHeight
        }));
        document.dispatchEvent(new KeyboardEvent('keydown', {
          key: 'Shift',
          code: 'ShiftLeft',
          bubbles: true
        }));
      })();
    ''');
  }

  void _cancelReload() {
    _reloadTimer?.cancel();
    _reloadTimer = null;
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
