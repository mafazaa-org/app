import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../constants/colors.dart';
import '../utils/youtube_video_id.dart';

class EmbeddedYoutubePlayer extends StatefulWidget {
  const EmbeddedYoutubePlayer({super.key, required this.videoUrl});

  final String videoUrl;

  @override
  State<EmbeddedYoutubePlayer> createState() => _EmbeddedYoutubePlayerState();
}

class _EmbeddedYoutubePlayerState extends State<EmbeddedYoutubePlayer> {
  static const _appOrigin = 'https://mafazaa.com';

  late final WebViewController _controller;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

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

    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant EmbeddedYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) _loadVideo();
  }

  Future<void> _loadVideo() async {
    final videoId = extractYoutubeVideoId(widget.videoUrl);
    if (videoId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'رابط الفيديو غير صالح.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    final playerUrl =
        Uri.https('www.youtube-nocookie.com', '/embed/$videoId', const {
          'playsinline': '1',
          'rel': '0',
          'fs': '0',
          'enablejsapi': '1',
          'hl': 'ar',
          'origin': _appOrigin,
          'widget_referrer': _appOrigin,
        });

    await _controller.loadHtmlString(
      _playerHtml(playerUrl),
      baseUrl: _appOrigin,
    );
  }

  String _playerHtml(Uri playerUrl) =>
      '''
<!doctype html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    <style>
      html, body { margin: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
      iframe { display: block; width: 100%; height: 100%; border: 0; }
    </style>
  </head>
  <body>
    <iframe
      src="$playerUrl"
      title="مشغل درس مفازا"
      referrerpolicy="strict-origin-when-cross-origin"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share">
    </iframe>
  </body>
</html>
''';

  @override
  Widget build(BuildContext context) {
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
