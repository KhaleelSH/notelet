import 'package:material_ui/material_ui.dart';

/// Maps an icon name from JSON (e.g. `"sparkles"`) to the [IconData] shown
/// next to a list row.
typedef NoteletIconResolver = IconData Function(String name);

/// The icon used for list rows decoded from JSON without a
/// [NoteletIconResolver].
const IconData noteletFallbackIcon = Icons.auto_awesome;

/// Release notes for a single app version.
class NoteletVersionNotes {
  const NoteletVersionNotes({required this.version, required this.items});

  /// Decodes notes from JSON, e.g. when loading them remotely at runtime.
  ///
  /// ```json
  /// {
  ///   "version": "1.2.0",
  ///   "items": [
  ///     {
  ///       "type": "list",
  ///       "title": "What's new",
  ///       "rows": [
  ///         {"icon": "sparkles", "title": "Polished details", "description": "Small UI upgrades."}
  ///       ]
  ///     },
  ///     {
  ///       "type": "image",
  ///       "url": "https://example.com/preview.jpg",
  ///       "title": "UI preview",
  ///       "description": "A quick look at the redesign."
  ///     },
  ///     {
  ///       "type": "image",
  ///       "asset": "assets/release_notes/archive.png",
  ///       "title": "Journal Archive",
  ///       "description": "Archive entries without deleting them."
  ///     },
  ///     {
  ///       "type": "video",
  ///       "url": "https://example.com/demo.mp4",
  ///       "title": "Feature demo",
  ///       "description": "See the flow in action."
  ///     }
  ///   ]
  /// }
  /// ```
  ///
  /// Images and videos have either a `url` or an `asset`, decoded as
  /// [NoteletMediaSource.network] or [NoteletMediaSource.asset].
  ///
  /// Row icons are looked up with [iconResolver]. Without one, every row uses
  /// [noteletFallbackIcon].
  factory NoteletVersionNotes.fromJson(
    Map<String, Object?> json, {
    NoteletIconResolver? iconResolver,
  }) {
    return switch (json) {
      {'version': final String version, 'items': final List<Object?> items} =>
        NoteletVersionNotes(
          version: version,
          items: [
            for (final item in items)
              NoteletVersionNoteItem.fromJson(
                _asJsonObject(item),
                iconResolver: iconResolver,
              ),
          ],
        ),
      _ => throw FormatException('Invalid Notelet version notes', json),
    };
  }

  /// The app version these notes belong to, e.g. `"1.2.0"`.
  ///
  /// Compared against the app's version name (`CFBundleShortVersionString` on
  /// iOS, `versionName` on Android) when presenting
  /// [NoteletPresentedVersion.current].
  final String version;

  /// The notes, shown as pages in this order.
  final List<NoteletVersionNoteItem> items;
}

/// A single page of release notes.
sealed class NoteletVersionNoteItem {
  const NoteletVersionNoteItem();

  /// An image shown in a square container, with a title and description
  /// below it.
  ///
  /// Non-square images are cropped to fill the container, so keep the main
  /// subject centered.
  const factory NoteletVersionNoteItem.image({
    required NoteletMediaSource image,
    required String title,
    required String description,
  }) = NoteletImageNoteItem;

  /// A muted, looping video shown in a square container, with a title and
  /// description below it. It plays while its page is visible.
  ///
  /// Non-square videos are cropped to fill the container, so keep the main
  /// subject centered.
  const factory NoteletVersionNoteItem.video({
    required NoteletMediaSource video,
    required String title,
    required String description,
  }) = NoteletVideoNoteItem;

  /// A title followed by rows, each with an icon, a title and a description.
  const factory NoteletVersionNoteItem.list({
    required String title,
    required List<NoteletListRow> rows,
  }) = NoteletListNoteItem;

  /// Decodes a note item. See [NoteletVersionNotes.fromJson] for the format.
  factory NoteletVersionNoteItem.fromJson(
    Map<String, Object?> json, {
    NoteletIconResolver? iconResolver,
  }) {
    return switch (json) {
      {
        'type': 'image',
        'title': final String title,
        'description': final String description,
      } =>
        NoteletImageNoteItem(
          image: _mediaSourceFromJson(json),
          title: title,
          description: description,
        ),
      {
        'type': 'video',
        'title': final String title,
        'description': final String description,
      } =>
        NoteletVideoNoteItem(
          video: _mediaSourceFromJson(json),
          title: title,
          description: description,
        ),
      {
        'type': 'list',
        'title': final String title,
        'rows': final List<Object?> rows,
      } =>
        NoteletListNoteItem(
          title: title,
          rows: [
            for (final row in rows)
              NoteletListRow.fromJson(
                _asJsonObject(row),
                iconResolver: iconResolver,
              ),
          ],
        ),
      _ => throw FormatException('Invalid Notelet note item', json),
    };
  }
}

/// See [NoteletVersionNoteItem.image].
final class NoteletImageNoteItem extends NoteletVersionNoteItem {
  const NoteletImageNoteItem({
    required this.image,
    required this.title,
    required this.description,
  });

  final NoteletMediaSource image;
  final String title;
  final String description;
}

/// See [NoteletVersionNoteItem.video].
final class NoteletVideoNoteItem extends NoteletVersionNoteItem {
  const NoteletVideoNoteItem({
    required this.video,
    required this.title,
    required this.description,
  });

  final NoteletMediaSource video;
  final String title;
  final String description;
}

/// Where the image of a [NoteletVersionNoteItem.image] or the video of a
/// [NoteletVersionNoteItem.video] comes from.
sealed class NoteletMediaSource {
  const NoteletMediaSource._();

  /// Media downloaded or streamed from [url].
  const factory NoteletMediaSource.network(String url) = NoteletNetworkSource;

  /// Media bundled with the app, so it shows even when the user is offline.
  ///
  /// [name] is the asset's path, as declared under `flutter: assets:` in the
  /// app's `pubspec.yaml`.
  const factory NoteletMediaSource.asset(String name) = NoteletAssetSource;
}

/// See [NoteletMediaSource.network].
final class NoteletNetworkSource extends NoteletMediaSource {
  const NoteletNetworkSource(this.url) : super._();

  final String url;

  @override
  bool operator ==(Object other) =>
      other is NoteletNetworkSource && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// See [NoteletMediaSource.asset].
final class NoteletAssetSource extends NoteletMediaSource {
  const NoteletAssetSource(this.name) : super._();

  final String name;

  @override
  bool operator ==(Object other) =>
      other is NoteletAssetSource && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// See [NoteletVersionNoteItem.list].
final class NoteletListNoteItem extends NoteletVersionNoteItem {
  const NoteletListNoteItem({required this.title, required this.rows});

  final String title;
  final List<NoteletListRow> rows;
}

/// A row of a [NoteletVersionNoteItem.list] note.
class NoteletListRow {
  const NoteletListRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  /// Decodes a row, resolving its `icon` name with [iconResolver].
  factory NoteletListRow.fromJson(
    Map<String, Object?> json, {
    NoteletIconResolver? iconResolver,
  }) {
    return switch (json) {
      {
        'icon': final String icon,
        'title': final String title,
        'description': final String description,
      } =>
        NoteletListRow(
          icon: iconResolver?.call(icon) ?? noteletFallbackIcon,
          title: title,
          description: description,
        ),
      _ => throw FormatException('Invalid Notelet list row', json),
    };
  }

  /// Shown in the accent color, e.g. `Icons.auto_awesome` or
  /// `CupertinoIcons.wand_stars`.
  final IconData icon;
  final String title;
  final String description;
}

/// Which version's notes to present.
sealed class NoteletPresentedVersion {
  const NoteletPresentedVersion._();

  /// The app's own version.
  ///
  /// Notes are only shown if the user hasn't seen this version yet, and the
  /// version is marked as seen when the sheet is dismissed.
  static const NoteletPresentedVersion current = NoteletCurrentVersion._();

  /// A specific version, shown every time, e.g. for a changelog in settings.
  const factory NoteletPresentedVersion.v(String version) =
      NoteletSpecificVersion;
}

/// See [NoteletPresentedVersion.current].
final class NoteletCurrentVersion extends NoteletPresentedVersion {
  const NoteletCurrentVersion._() : super._();
}

/// See [NoteletPresentedVersion.v].
final class NoteletSpecificVersion extends NoteletPresentedVersion {
  const NoteletSpecificVersion(this.version) : super._();

  final String version;

  @override
  bool operator ==(Object other) =>
      other is NoteletSpecificVersion && other.version == version;

  @override
  int get hashCode => version.hashCode;
}

/// How tall the sheet is on phones in portrait. Phones in landscape always use
/// the full height, and tablets show a centered card instead.
enum NoteletSheetHeight {
  /// 85% of the available height, leaving a sliver of the presenting screen
  /// visible.
  standard,

  /// The full available height.
  full,
}

class NoteletConfiguration {
  const NoteletConfiguration({
    this.nextButtonLabel = 'Next',
    this.doneButtonLabel = 'Done',
    this.pageIndicatorLabel = _defaultPageIndicatorLabel,
    this.imageLabel = 'Image',
    this.imageLoadingLabel = 'Loading image',
    this.imageFailedLabel = 'Image failed to load',
    this.videoLabel = 'Video',
    this.videoLoadingLabel = 'Loading video',
    this.videoFailedLabel = 'Video failed to load',
    this.accentColor,
    this.sheetHeight = NoteletSheetHeight.standard,
  });

  final String nextButtonLabel;
  final String doneButtonLabel;

  /// What screen readers announce for the page indicator, e.g. "Page 1 of 3".
  ///
  /// Called with the current page, counting from 1, and the number of pages.
  final String Function(int page, int pageCount) pageIndicatorLabel;

  /// What screen readers announce before an image note's title and
  /// description once the image has loaded.
  final String imageLabel;

  /// Like [imageLabel], while the image is loading.
  final String imageLoadingLabel;

  /// Like [imageLabel], when the image failed to load.
  final String imageFailedLabel;

  /// Like [imageLabel], for video notes.
  final String videoLabel;

  /// Like [imageLoadingLabel], for video notes.
  final String videoLoadingLabel;

  /// Like [imageFailedLabel], for video notes.
  final String videoFailedLabel;

  /// Tints the button and list icons. Defaults to the theme's primary color.
  final Color? accentColor;

  final NoteletSheetHeight sheetHeight;
}

String _defaultPageIndicatorLabel(int page, int pageCount) =>
    'Page $page of $pageCount';

/// Reads an image or video note's `url` or `asset`.
NoteletMediaSource _mediaSourceFromJson(Map<String, Object?> json) {
  return switch ((json['url'], json['asset'])) {
    (final String url, null) => NoteletMediaSource.network(url),
    (null, final String name) => NoteletMediaSource.asset(name),
    _ => throw FormatException(
      'A Notelet ${json['type']} needs either a "url" or an "asset"',
      json,
    ),
  };
}

Map<String, Object?> _asJsonObject(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }

  throw FormatException('Expected a JSON object', value);
}
