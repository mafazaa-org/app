import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../constants/colors.dart';
import '../utils/youtube_video_id.dart';

class EmbeddedYoutubePlayer extends StatefulWidget {
  const EmbeddedYoutubePlayer({
    super.key,
    required this.videoUrl,
    this.startSecond,
    this.endSecond,
  });

  final String videoUrl;
  final int? startSecond;
  final int? endSecond;

  @override
  State<EmbeddedYoutubePlayer> createState() => _EmbeddedYoutubePlayerState();
}

class _EmbeddedYoutubePlayerState extends State<EmbeddedYoutubePlayer> {
  static const _appOrigin = 'https://mafazaa.com';

  late final WebViewController _controller;
  bool _loading = true;
  String? _errorMessage;
  bool _partFinishedMessageShown = false;
  late bool _showRangeIntro;

  bool get _hasLimitedRange {
    return widget.startSecond != null || widget.endSecond != null;
  }

  int get _effectiveStartSecond {
    return widget.startSecond ?? 0;
  }

  @override
  void initState() {
    super.initState();

    _showRangeIntro = _hasLimitedRange;

    late final PlatformWebViewControllerCreationParams creationParams;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      creationParams = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      creationParams = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(creationParams)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'LessonBoundary',
        onMessageReceived: _handleLessonBoundaryMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) return;
            setState(() {
              _loading = false;
              _errorMessage =
                  'تعذر تحميل مشغل الفيديو. تحقق من الاتصال وحاول مرة أخرى.';
            });
          },
          onNavigationRequest: (request) {
            if (!request.isMainFrame) return NavigationDecision.navigate;

            final uri = Uri.tryParse(request.url);
            final isAppDocument =
                uri != null &&
                (uri.host == Uri.parse(_appOrigin).host ||
                    uri.scheme == 'about' ||
                    uri.scheme == 'data');

            return isAppDocument
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );

    final platformController = _controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setMediaPlaybackRequiresUserGesture(false);
    }

    if (!_showRangeIntro) {
      _loadVideo();
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant EmbeddedYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.startSecond != widget.startSecond ||
        oldWidget.endSecond != widget.endSecond) {
      _partFinishedMessageShown = false;
      _showRangeIntro = _hasLimitedRange;

      if (_showRangeIntro) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMessage = null;
          });
        }
      } else {
        _loadVideo();
      }
    }
  }

  void _handleLessonBoundaryMessage(JavaScriptMessage message) {
    try {
      final payload = jsonDecode(message.message);
      if (payload is! Map<String, dynamic>) return;
      if (payload['type'] != 'partFinished') return;
      if (_partFinishedMessageShown || !mounted) return;

      _partFinishedMessageShown = true;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'أحسنت! لقد أنهيت الجزء المطلوب من فيديو اليوم. يمكنك الآن تحديد الدرس كمكتمل.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
    } catch (_) {
      // Ignore malformed JavaScript messages.
    }
  }

  Future<void> _startLimitedRangeVideo() async {
    setState(() {
      _showRangeIntro = false;
      _loading = true;
      _errorMessage = null;
    });

    await _loadVideo();
  }

  Future<void> _loadVideo() async {
    _partFinishedMessageShown = false;

    final videoId = extractYoutubeVideoId(widget.videoUrl);
    if (videoId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'رابط الفيديو غير صالح.';
      });
      return;
    }

    final startSecond = _effectiveStartSecond;
    final endSecond = widget.endSecond;

    if (endSecond != null && endSecond <= startSecond) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'نطاق وقت الفيديو غير صحيح.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    await _controller.loadHtmlString(
      _playerHtml(
        videoId: videoId,
        startSecond: startSecond,
        endSecond: endSecond,
      ),
      baseUrl: _appOrigin,
    );
  }

  String _playerHtml({
    required String videoId,
    required int startSecond,
    required int? endSecond,
  }) {
    final videoIdJson = jsonEncode(videoId);
    final originJson = jsonEncode(_appOrigin);
    final endSecondJs = endSecond == null ? 'null' : '$endSecond';
    final endPlayerVar = endSecond == null ? '' : ', end: $endSecond';

    return '''
<!doctype html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">

    <style>
      html, body {
        margin: 0;
        width: 100%;
        height: 100%;
        background: #000;
        overflow: hidden;
      }

      #player {
        width: 100%;
        height: 100%;
      }
    </style>
  </head>

  <body>
    <div id="player"></div>

    <script>
      const videoId = $videoIdJson;
      const appOrigin = $originJson;
      const startSecond = $startSecond;
      const endSecond = $endSecondJs;

      let player = null;
      let rangeGuard = null;
      let finishMessageSent = false;

      function sendToFlutter(type, data = {}) {
        if (window.LessonBoundary && window.LessonBoundary.postMessage) {
          window.LessonBoundary.postMessage(JSON.stringify({
            type: type,
            ...data
          }));
        }
      }

      function loadIframeApi() {
        const tag = document.createElement('script');
        tag.src = 'https://www.youtube.com/iframe_api';

        const firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
      }

      function onYouTubeIframeAPIReady() {
        player = new YT.Player('player', {
          width: '100%',
          height: '100%',
          videoId: videoId,
          playerVars: {
            playsinline: 1,
            rel: 0,
            fs: 0,
            disablekb: 1,
            hl: 'ar',
            origin: appOrigin,
            widget_referrer: appOrigin,
            start: startSecond
            $endPlayerVar
          },
          events: {
            onReady: onPlayerReady,
            onStateChange: onPlayerStateChange
          }
        });
      }

      function onPlayerReady() {
        if (startSecond > 0) {
          player.seekTo(startSecond, true);
          player.pauseVideo();
        }
      }

      function onPlayerStateChange(event) {
        if (event.data === YT.PlayerState.PLAYING) {
          startRangeGuard();
        } else {
          stopRangeGuard();
        }
      }

      function startRangeGuard() {
        if (rangeGuard !== null || player === null) return;

        rangeGuard = setInterval(() => {
          if (player === null) return;

          let currentTime = 0;

          try {
            currentTime = player.getCurrentTime();
          } catch (_) {
            return;
          }

          if (currentTime < startSecond - 1) {
            player.seekTo(startSecond, true);
            return;
          }

          if (endSecond !== null && currentTime >= endSecond - 0.25) {
            stopRangeGuard();
            player.pauseVideo();

            if (!finishMessageSent) {
              finishMessageSent = true;
              sendToFlutter('partFinished', {
                endSecond: endSecond,
                currentTime: currentTime
              });
            }
          }
        }, 250);
      }

      function stopRangeGuard() {
        if (rangeGuard !== null) {
          clearInterval(rangeGuard);
          rangeGuard = null;
        }
      }

      window.onYouTubeIframeAPIReady = onYouTubeIframeAPIReady;
      loadIframeApi();
    </script>
  </body>
</html>
''';
  }

  String _formatDuration(int seconds) {
    final totalMinutes = (seconds / 60).round();

    if (totalMinutes < 60) {
      return '$totalMinutes دقيقة';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '$hours ساعة';
    }

    return '$hours ساعة و $minutes دقيقة';
  }

  String _formatMinutePosition(int seconds) {
    final totalMinutes = (seconds / 60).round();

    if (totalMinutes < 60) {
      return 'الدقيقة $totalMinutes';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return 'الساعة $hours';
    }

    return 'الساعة $hours والدقيقة $minutes';
  }

  String _rangeIntroTitle() {
    final startSecond = _effectiveStartSecond;
    final endSecond = widget.endSecond;

    if (startSecond == 0 && endSecond != null) {
      return 'المطلوب اليوم هو أول ${_formatDuration(endSecond)} فقط';
    }

    if (startSecond > 0 && endSecond != null) {
      final duration = endSecond - startSecond;
      return 'المطلوب اليوم هو مشاهدة ${_formatDuration(duration)} فقط';
    }

    if (startSecond > 0 && endSecond == null) {
      return 'المطلوب اليوم يبدأ من ${_formatMinutePosition(startSecond)}';
    }

    return 'المطلوب اليوم هو جزء محدد من الفيديو';
  }

  String _rangeIntroSubtitle() {
    final startSecond = _effectiveStartSecond;
    final endSecond = widget.endSecond;

    if (startSecond == 0 && endSecond != null) {
      return 'لا تقلق من مدة الفيديو الظاهرة في شريط يوتيوب. سيتم إيقاف الفيديو تلقائيًا عند نهاية الجزء المطلوب.';
    }

    if (startSecond > 0 && endSecond != null) {
      return 'سيبدأ الفيديو من ${_formatMinutePosition(startSecond)} ويتوقف عند ${_formatMinutePosition(endSecond)}.';
    }

    if (startSecond > 0 && endSecond == null) {
      return 'لا تحتاج إلى مشاهدة بداية الفيديو. التطبيق سيبدأ من الجزء المطلوب مباشرة.';
    }

    return 'التطبيق سيعرض لك الجزء المطلوب فقط من هذا الفيديو.';
  }

  Widget _rangeIntroScreen() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppColors.accent,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                _rangeIntroTitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _rangeIntroSubtitle(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _startLimitedRangeVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'ابدأ مشاهدة الجزء المطلوب',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
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
    if (_showRangeIntro) {
      return _rangeIntroScreen();
    }

    if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          ),
      ],
    );
  }
}
