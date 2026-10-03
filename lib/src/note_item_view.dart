import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'bullet_list_note_item_view.dart';
import 'media_load_state.dart';
import 'media_note_item_image_view.dart';
import 'media_note_item_video_view.dart';
import 'types.dart';

class NoteItemView extends StatelessWidget {
  const NoteItemView({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.configuration,
  });

  final NoteletVersionNoteItem item;
  final bool isCurrent;
  final NoteletConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      NoteletImageNoteItem(:final image, :final title, :final description) =>
        _MediaNoteItemView(
          kind: _MediaKind.image,
          title: title,
          description: description,
          configuration: configuration,
          buildMedia: (onLoadStateChange) => MediaNoteItemImageView(
            key: ValueKey(image),
            image: image,
            onLoadStateChange: onLoadStateChange,
          ),
        ),
      NoteletVideoNoteItem(:final video, :final title, :final description) =>
        _MediaNoteItemView(
          kind: _MediaKind.video,
          title: title,
          description: description,
          configuration: configuration,
          buildMedia: (onLoadStateChange) => MediaNoteItemVideoView(
            key: ValueKey(video),
            video: video,
            isPlaying: isCurrent,
            onLoadStateChange: onLoadStateChange,
          ),
        ),
      NoteletListNoteItem(:final title, :final rows) => BulletListNoteItemView(
        title: title,
        rows: rows,
        accentColor:
            configuration.accentColor ?? Theme.of(context).colorScheme.primary,
      ),
    };
  }
}

enum _MediaKind { image, video }

/// An image or video in a square card, with a title and description below.
class _MediaNoteItemView extends StatefulWidget {
  const _MediaNoteItemView({
    required this.kind,
    required this.title,
    required this.description,
    required this.configuration,
    required this.buildMedia,
  });

  final _MediaKind kind;
  final String title;
  final String description;
  final NoteletConfiguration configuration;
  final Widget Function(ValueChanged<MediaNoteItemLoadState> onLoadStateChange)
  buildMedia;

  @override
  State<_MediaNoteItemView> createState() => _MediaNoteItemViewState();
}

class _MediaNoteItemViewState extends State<_MediaNoteItemView> {
  static const _mediaPadding = 16.0;
  static const _cornerRadius = BorderRadius.all(Radius.circular(24));

  MediaNoteItemLoadState _loadState = MediaNoteItemLoadState.loading;

  void _onLoadStateChange(MediaNoteItemLoadState state) {
    // Media views can report while building, so rebuild once the current
    // frame is done.
    scheduleMicrotask(() {
      if (mounted && state != _loadState) {
        setState(() => _loadState = state);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 440 points is the widest iPhone. Clamping to it keeps the media
        // phone-sized on tablets and in landscape.
        final containerWidth = clampDouble(constraints.maxWidth, 300, 440);
        final mediaSize = containerWidth - _mediaPadding * 2;

        return Semantics(
          container: true,
          label: _accessibilityLabel(),
          excludeSemantics: true,
          child: Column(
            spacing: 12,
            children: [
              Padding(
                padding: const EdgeInsets.all(_mediaPadding),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: _cornerRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: _cornerRadius,
                    child: SizedBox.square(
                      dimension: mediaSize,
                      child: widget.buildMedia(_onLoadStateChange),
                    ),
                  ),
                ),
              ),
              _MediaNoteItemDetailsView(
                title: widget.title,
                description: widget.description,
              ),
            ],
          ),
        );
      },
    );
  }

  String _accessibilityLabel() {
    final configuration = widget.configuration;
    final media = switch ((widget.kind, _loadState)) {
      (_MediaKind.image, MediaNoteItemLoadState.loading) =>
        configuration.imageLoadingLabel,
      (_MediaKind.image, MediaNoteItemLoadState.loaded) =>
        configuration.imageLabel,
      (_MediaKind.image, MediaNoteItemLoadState.failed) =>
        configuration.imageFailedLabel,
      (_MediaKind.video, MediaNoteItemLoadState.loading) =>
        configuration.videoLoadingLabel,
      (_MediaKind.video, MediaNoteItemLoadState.loaded) =>
        configuration.videoLabel,
      (_MediaKind.video, MediaNoteItemLoadState.failed) =>
        configuration.videoFailedLabel,
    };

    return '$media. ${widget.title}. ${widget.description}';
  }
}

class _MediaNoteItemDetailsView extends StatelessWidget {
  const _MediaNoteItemDetailsView({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(description, style: textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
