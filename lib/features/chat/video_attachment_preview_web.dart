import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class VideoAttachmentPreview extends StatefulWidget {
  const VideoAttachmentPreview({required this.url, super.key});

  final String url;

  @override
  State<VideoAttachmentPreview> createState() => _VideoAttachmentPreviewState();
}

class _VideoAttachmentPreviewState extends State<VideoAttachmentPreview> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'maia-video-preview-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final video = web.HTMLVideoElement()
        ..src = _previewUrl(widget.url)
        ..preload = 'metadata'
        ..muted = true
        ..controls = false
        ..autoplay = false;

      video
        ..setAttribute('playsinline', '')
        ..setAttribute('webkit-playsinline', '')
        ..setAttribute('muted', '')
        ..setAttribute('aria-hidden', 'true');

      video.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'cover'
        ..display = 'block'
        ..pointerEvents = 'none';

      video.onLoadedMetadata.listen((_) {
        try {
          if (video.currentTime < 0.09) {
            video.currentTime = 0.1;
          }
        } catch (_) {
          // Some signed media URLs do not allow programmatic seeking until the
          // fragment seek completes. The URL fragment still nudges iOS to paint.
        }
      });

      return video;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}

String _previewUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return url.contains('#') ? url : '$url#t=0.1';
  }
  if (uri.fragment.isNotEmpty) {
    return url;
  }
  return uri.replace(fragment: 't=0.1').toString();
}
