import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import 'media_load_state.dart';
import 'types.dart';

/// A muted, looping video that plays while [isPlaying] is true.
class MediaNoteItemVideoView extends StatefulWidget {
  const MediaNoteItemVideoView({
    super.key,
    required this.video,
    required this.isPlaying,
    required this.onLoadStateChange,
  });

  final NoteletMediaSource video;
  final bool isPlaying;
  final ValueChanged<MediaNoteItemLoadState> onLoadStateChange;

  @override
  State<MediaNoteItemVideoView> createState() => _MediaNoteItemVideoViewState();
}

class _MediaNoteItemVideoViewState extends State<MediaNoteItemVideoView> {
  // Don't interrupt whatever the user is listening to.
  static final _options = VideoPlayerOptions(mixWithOthers: true);

  late final VideoPlayerController _controller = switch (widget.video) {
    NoteletNetworkSource(:final url) => VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: _options,
    ),
    NoteletAssetSource(:final name) => VideoPlayerController.asset(
      name,
      videoPlayerOptions: _options,
    ),
  };

  MediaNoteItemLoadState _loadState = MediaNoteItemLoadState.loading;

  @override
  void initState() {
    super.initState();
    // Catches errors after loading too, e.g. a stream that breaks mid-playback.
    _controller.addListener(_onControllerChanged);
    _prepareVideo();
  }

  @override
  void didUpdateWidget(MediaNoteItemVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPlaying != oldWidget.isPlaying) {
      _updatePlaybackState();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prepareVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      // The video player plays through the silent switch, so autoplaying
      // release notes stay silent.
      await _controller.setVolume(0);
    } catch (_) {
      _setLoadState(MediaNoteItemLoadState.failed);
      return;
    }

    _setLoadState(MediaNoteItemLoadState.loaded);
    _updatePlaybackState();
  }

  Future<void> _updatePlaybackState() async {
    if (_loadState != MediaNoteItemLoadState.loaded) {
      return;
    }

    try {
      if (widget.isPlaying) {
        await _controller.play();
      } else {
        await _controller.pause();
      }
    } catch (_) {
      _setLoadState(MediaNoteItemLoadState.failed);
    }
  }

  void _onControllerChanged() {
    if (_controller.value.hasError) {
      _setLoadState(MediaNoteItemLoadState.failed);
    }
  }

  void _setLoadState(MediaNoteItemLoadState state) {
    // A failed video stays failed, even if loading finishes after the error.
    if (!mounted || _loadState == MediaNoteItemLoadState.failed) {
      return;
    }

    setState(() => _loadState = state);
    widget.onLoadStateChange(state);
  }

  @override
  Widget build(BuildContext context) {
    final videoSize = _controller.value.size;

    return switch (_loadState) {
      MediaNoteItemLoadState.loading => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
      MediaNoteItemLoadState.loaded when !videoSize.isEmpty => FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.fromSize(
          size: videoSize,
          child: VideoPlayer(_controller),
        ),
      ),
      MediaNoteItemLoadState.loaded => VideoPlayer(_controller),
      MediaNoteItemLoadState.failed => const MediaNoteItemFailedView(
        icon: Icons.videocam_off_rounded,
      ),
    };
  }
}
