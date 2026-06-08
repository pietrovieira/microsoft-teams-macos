import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  SharedPreferences? _prefs;
  Timer? _keepAliveTimer;
  Timer? _reloadTimer;
  bool _isLoading = true;
  double _progress = 0;
  bool _permissionsGranted = false;
  bool _pageLoaded = false;

  static const String _kNotificationPermissionKey = 'notification_permission_granted';
  static const String _kMediaPermissionKey = 'media_permission_granted';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPrefs();
    _setupPlatformChannel();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/125.0.0.0 Safari/537.36',
      )
      ..addJavaScriptChannel(
        'TeamsApp',
        onMessageReceived: (JavaScriptMessage message) {
          final data = message.message;
          if (data == 'notification_granted') {
            _markNotificationPermissionGranted();
          } else if (data == 'media_granted') {
            _markMediaPermissionGranted();
          }
        },
      )
      ..addJavaScriptChannel(
        'ConsoleLog',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('JS Console: ${message.message}');
        },
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
            _pageLoaded = true;
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
            debugPrint('WebResourceError: ${error.description} (code: ${error.errorCode}, type: ${error.errorType})');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://teams.cloud.microsoft/'));
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
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
      // Nao recarrega o webview ao voltar ao app para nao perder estado
    } else {
      _keepAliveTimer?.cancel();
    }
  }

  void _onPageLoaded() {
    _injectNotificationHandler();
    _injectPopupHandler();
    _injectImageFix();
    _requestMediaAccess();
    _startKeepAlive();
    _cancelReload();
  }

  Future<bool> _shouldRequestNotificationPermission() async {
    if (_prefs == null) return true;
    final granted = _prefs!.getBool(_kNotificationPermissionKey);
    if (granted == true) return false;
    return true;
  }

  Future<void> _markNotificationPermissionGranted() async {
    if (_prefs == null) return;
    await _prefs!.setBool(_kNotificationPermissionKey, true);
  }

  Future<bool> _shouldRequestMediaPermission() async {
    if (_prefs == null) return true;
    final granted = _prefs!.getBool(_kMediaPermissionKey);
    if (granted == true) return false;
    return true;
  }

  Future<void> _markMediaPermissionGranted() async {
    if (_prefs == null) return;
    await _prefs!.setBool(_kMediaPermissionKey, true);
  }

  Future<void> _injectNotificationHandler() async {
    final shouldRequest = await _shouldRequestNotificationPermission();
    if (!shouldRequest) return;

    await _controller.runJavaScript('''
      (function() {
        if (typeof Notification !== 'undefined') {
          if (Notification.permission === 'default') {
            Notification.requestPermission().then(function(permission) {
              if (permission === 'granted') {
                if (window.TeamsApp) {
                  window.TeamsApp.postMessage('notification_granted');
                }
              }
            });
          } else if (Notification.permission === 'granted') {
            if (window.TeamsApp) {
              window.TeamsApp.postMessage('notification_granted');
            }
          }
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

  Future<void> _injectImageFix() async {
    await _controller.runJavaScript('''
      (function() {
        if (window.__imageFixInjected) return;
        window.__imageFixInjected = true;

        var _origError = console.error;
        var _origWarn = console.warn;
        console.error = function() {
          var msg = Array.from(arguments).join(' ');
          if (window.ConsoleLog) window.ConsoleLog.postMessage('ERROR: ' + msg);
          _origError.apply(console, arguments);
        };
        console.warn = function() {
          var msg = Array.from(arguments).join(' ');
          if (window.ConsoleLog) window.ConsoleLog.postMessage('WARN: ' + msg);
          _origWarn.apply(console, arguments);
        };

        function reloadImage(img) {
          var originalSrc = img.src || img.getAttribute('src');
          if (!originalSrc || originalSrc.indexOf('data:') === 0) return false;
          var attempts = parseInt(img.getAttribute('data-reload-attempts') || '0');
          if (attempts >= 3) return false;
          img.setAttribute('data-reload-attempts', (attempts + 1).toString());
          var cleanSrc = originalSrc;
          var idx = cleanSrc.indexOf('_t=');
          if (idx !== -1) {
            var before = cleanSrc.substring(0, idx);
            var afterIdx = cleanSrc.indexOf('&', idx);
            var after = afterIdx !== -1 ? cleanSrc.substring(afterIdx + 1) : '';
            if (after) {
              cleanSrc = before + after;
            } else {
              if (before.endsWith('?') || before.endsWith('&')) {
                cleanSrc = before.slice(0, -1);
              } else {
                cleanSrc = before;
              }
            }
          }
          var separator = cleanSrc.indexOf('?') !== -1 ? '&' : '?';
          img.src = cleanSrc + separator + '_t=' + Date.now();
          return true;
        }

        function fixImages() {
          var images = document.querySelectorAll('img');
          var fixed = 0;
          images.forEach(function(img) {
            if (!img.complete || img.naturalWidth === 0) {
              if (reloadImage(img)) fixed++;
            }
          });
          if (window.ConsoleLog && fixed > 0) {
            window.ConsoleLog.postMessage('Fixed ' + fixed + ' broken images');
          }
        }

        var _originalFetch = window.fetch;
        window.fetch = function() {
          return _originalFetch.apply(this, arguments).catch(function(err) {
            if (window.ConsoleLog) window.ConsoleLog.postMessage('Fetch failed: ' + err);
            throw err;
          });
        };

        document.addEventListener('error', function(e) {
          var target = e.target;
          if (target && target.tagName === 'IMG') {
            if (window.ConsoleLog) window.ConsoleLog.postMessage('IMG ERROR: ' + target.src);
            reloadImage(target);
          }
        }, true);

        var observer = new MutationObserver(function(mutations) {
          fixImages();
        });
        observer.observe(document.body || document.documentElement, {
          childList: true,
          subtree: true
        });

        setTimeout(fixImages, 1000);
        setTimeout(fixImages, 3000);
        setTimeout(fixImages, 5000);
        setInterval(fixImages, 10000);
      })();
    ''');
  }

  Future<void> _requestMediaAccess() async {
    final shouldRequest = await _shouldRequestMediaPermission();
    if (!shouldRequest) return;

    const js = '''
      (function() {
        try {
          var checkAndRequest = function() {
            navigator.mediaDevices.getUserMedia({ audio: true, video: true })
              .then(function(stream) {
                stream.getTracks().forEach(function(track) { track.stop(); });
                if (window.TeamsApp) {
                  window.TeamsApp.postMessage('media_granted');
                }
                return true;
              })
              .catch(function(e) {
                console.error('Media permission denied:', e);
                return false;
              });
          };
          
          if (navigator.permissions && navigator.permissions.query) {
            Promise.all([
              navigator.permissions.query({name: 'camera'}).catch(function() { return {state: 'prompt'}; }),
              navigator.permissions.query({name: 'microphone'}).catch(function() { return {state: 'prompt'}; })
            ]).then(function(results) {
              var cameraState = results[0].state;
              var micState = results[1].state;
              if (cameraState === 'granted' && micState === 'granted') {
                if (window.TeamsApp) {
                  window.TeamsApp.postMessage('media_granted');
                }
              } else if (cameraState !== 'denied' && micState !== 'denied') {
                checkAndRequest();
              }
            }).catch(function() {
              checkAndRequest();
            });
          } else {
            checkAndRequest();
          }
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
      const Duration(seconds: 30),
      (_) => _injectActivity(),
    );
    // Executa imediatamente uma vez
    _injectActivity();
  }

  Future<void> _injectActivity() async {
    await _controller.runJavaScript('''
      (function() {
        // Simula movimento do mouse
        document.dispatchEvent(new MouseEvent('mousemove', {
          view: window,
          bubbles: true,
          cancelable: true,
          clientX: Math.random() * window.innerWidth,
          clientY: Math.random() * window.innerHeight
        }));
        
        // Simula tecla pressionada
        document.dispatchEvent(new KeyboardEvent('keydown', {
          key: 'Shift',
          code: 'ShiftLeft',
          bubbles: true
        }));
        document.dispatchEvent(new KeyboardEvent('keyup', {
          key: 'Shift',
          code: 'ShiftLeft',
          bubbles: true
        }));
        
        // Simula scroll sutil
        window.scrollBy(0, 0);
        
        // Dispara evento de foco
        window.dispatchEvent(new Event('focus'));
        document.dispatchEvent(new Event('focus'));
        
        // Simula click em um elemento neutro
        var body = document.body;
        if (body) {
          body.dispatchEvent(new MouseEvent('click', {
            view: window,
            bubbles: true,
            cancelable: true,
            clientX: 0,
            clientY: 0
          }));
        }
        
        // Atualiza visibility state
        Object.defineProperty(document, 'visibilityState', {
          value: 'visible',
          writable: true
        });
        Object.defineProperty(document, 'hidden', {
          value: false,
          writable: true
        });
        document.dispatchEvent(new Event('visibilitychange'));
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
