import 'package:material_ui/material_ui.dart';

import 'media_load_state.dart';
import 'types.dart';

/// Fills its box with [image], cropping it to cover, and reports how loading
/// goes.
class MediaNoteItemImageView extends StatelessWidget {
  const MediaNoteItemImageView({
    super.key,
    required this.image,
    required this.onLoadStateChange,
  });

  final NoteletMediaSource image;

  /// Called while building, and again with the same state on rebuilds, e.g.
  /// for every frame of an animated image.
  final ValueChanged<MediaNoteItemLoadState> onLoadStateChange;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: switch (image) {
        NoteletNetworkSource(:final url) => NetworkImage(url),
        NoteletAssetSource(:final name) => AssetImage(name),
      },
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      frameBuilder: (context, child, frame, _) {
        if (frame == null) {
          onLoadStateChange(MediaNoteItemLoadState.loading);
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        onLoadStateChange(MediaNoteItemLoadState.loaded);
        return child;
      },
      errorBuilder: (context, _, _) {
        onLoadStateChange(MediaNoteItemLoadState.failed);
        return const MediaNoteItemFailedView(icon: Icons.broken_image_rounded);
      },
    );
  }
}
