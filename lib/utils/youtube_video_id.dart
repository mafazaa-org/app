String? extractYoutubeVideoId(String url) {
  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) return null;

  if (_isValidYoutubeVideoId(trimmedUrl)) {
    return trimmedUrl;
  }

  final normalizedUrl =
      trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')
      ? trimmedUrl
      : 'https://$trimmedUrl';

  final uri = Uri.tryParse(normalizedUrl);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  final pathSegments = uri.pathSegments;

  String? candidateId;

  if (host == 'youtu.be') {
    candidateId = pathSegments.isNotEmpty ? pathSegments.first : null;
  } else if (_youtubeHosts.contains(host)) {
    if (pathSegments.isEmpty || pathSegments.first == 'watch') {
      candidateId = uri.queryParameters['v'];
    } else if (_videoPathPrefixes.contains(pathSegments.first) &&
        pathSegments.length > 1) {
      candidateId = pathSegments[1];
    }
  }

  return _isValidYoutubeVideoId(candidateId) ? candidateId : null;
}

const _youtubeHosts = {
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtube-nocookie.com',
  'www.youtube-nocookie.com',
};

const _videoPathPrefixes = {
  'embed',
  'shorts',
  'live',
  'v',
};

final _youtubeVideoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

bool _isValidYoutubeVideoId(String? videoId) {
  return videoId != null && _youtubeVideoIdPattern.hasMatch(videoId);
}