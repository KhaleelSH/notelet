<div align="center">
  <h1>Notelet for Flutter</h1>
  <p>Flutter package for showing rich release notes in your app</p>

  <p>
    <a href="https://pub.dev/packages/notelet"><img src="https://img.shields.io/pub/v/notelet.svg?label=pub&color=0175C2" alt="pub version"></a>
    <a href="https://github.com/KhaleelSH/notelet/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
  </p>
</div>

A Flutter port of the [Notelet](https://github.com/mykolaharmash/notelet) SwiftUI package. It shows release notes as
pages in a bottom sheet, supports list, image and video notes, and remembers which version the user has already seen.

## Installation

```yaml
dependencies:
  notelet: ^1.0.0
```

On Android, release builds need the internet permission to load network images and videos. Add it to
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Notelet is built on [`material_ui`](https://pub.dev/packages/material_ui), the Material library that moved out of the
Flutter framework. It needs `material_ui`'s `MaterialApp` (or its `Theme` and `MaterialLocalizations`) above it; the
legacy `MaterialApp` from `package:flutter/material.dart` doesn't provide them. To migrate an app, run
`dart fix --apply --code=migrate_design_widgets`.

## Usage

Here is a full usage example to get started quickly. Below are more detailed explanations of how the component works and
all available APIs. A runnable version lives in [`example/`](example/lib/main.dart).

The examples use dot shorthands (`.current`, `.image(...)`). The full names work too, e.g.
`NoteletPresentedVersion.current` or `NoteletVersionNoteItem.image(...)`.

```dart
import 'package:material_ui/material_ui.dart';
import 'package:notelet/notelet.dart';

/// Release notes for different versions of the app.
/// There are three note types: .list, .image and .video.
const notes = <NoteletVersionNotes>[
  NoteletVersionNotes(
    version: '1.2.0',
    items: [
      .list(
        title: "What's new",
        rows: [
          NoteletListRow(
            icon: Icons.auto_fix_high,
            title: 'New editor tools',
            description: 'More formatting options with less taps.',
          ),
          NoteletListRow(
            icon: Icons.shield,
            title: 'Privacy update',
            description: 'Sensitive data handling is now stricter.',
          ),
        ],
      ),
      .image(
        image: .network('https://example.com/notes-image.jpg'),
        title: 'Updated UI',
        description: 'Refreshed visuals across key screens.',
      ),
      .video(
        video: .network('https://example.com/notes-video.mp4'),
        title: 'Quick walkthrough',
        description: 'A short clip showing the new flow.',
      ),
    ],
  ),
  NoteletVersionNotes(
    version: '1.2.1',
    items: [
      .image(
        image: .asset('assets/release_notes/archive.png'),
        title: 'Journal Archive',
        description: 'Archive entries without deleting them permanently',
      ),
    ],
  ),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap a screen with NoteletSheet. It takes the full list of notes for
    // all versions and the version you'd like to present to the user.
    return NoteletSheet(
      notes: notes,
      // `.current` takes the current version from the app and shows its notes
      // if they are present in `notes`. It also saves this version as "seen"
      // when the sheet is dismissed.
      version: .current,
      child: const Scaffold(body: Center(child: Text('Hello, World!'))),
    );
  }
}
```

## Release notes for the current version

The most common use case is to show release notes for the latest app update. Wrap a screen in `NoteletSheet` and use
`version: .current`.

```dart
NoteletSheet(
  notes: notes,
  version: .current,
  child: ...,
)
```

Notelet gets the current app version from the platform and shows its release notes. When the user dismisses the sheet,
Notelet marks the current version as seen, so the user doesn't see the same release notes again.

> [!IMPORTANT]
> Notelet reads the app's version name: `CFBundleShortVersionString` on iOS and `versionName` on Android. In Flutter
> both come from the part of `version` in `pubspec.yaml` before the `+` (`1.2.0` for `version: 1.2.0+42`). Use that
> version in `notes`.

`NoteletSheet` presents the sheet when it's first built and whenever `version` changes. If `notes` has nothing for that
version yet, for example while the notes load remotely, the sheet opens once `notes` does. Setting `version` to `null`
closes an open sheet without marking it as seen. To show the sheet from a button, call `showNoteletSheet()` instead:

```dart
FilledButton(
  onPressed: () => showNoteletSheet(
    context: context,
    notes: notes,
    version: .current,
  ),
  child: const Text('Show Release Notes'),
)
```

`showNoteletSheet()` follows the same rules as `NoteletSheet`. With `.current`, it shows nothing if the user has already
seen this version.

## Manually show notes for a specific version

You may also want to show release notes for app versions other than the current one, for example, to give users access
to a historical changelog in app settings. Notes for a specific version are shown every time and don't change the "seen"
state.

```dart
showNoteletSheet(
  context: context,
  notes: notes,
  version: .v('1.2.1'),
);
```

## Defining release notes

The release notes for each app version are a list of `NoteletVersionNotes`. Each one has a `version` and `items`.

You can have as many notes inside `items` for each version as needed. They're arranged as pages, with navigation using
either the "Next" button or swiping.

```dart
final releaseNotes = <NoteletVersionNotes>[
  NoteletVersionNotes(
    version: '1.2.0',
    items: [...], // <-- release notes go here
  ),
];
```

Text is plain `String`s, so pass already-localized strings. For example, build the list from your `AppLocalizations`
inside `build()`.

### Loading notes from JSON

To load notes remotely at runtime, decode them with `NoteletVersionNotes.fromJson`:

```json
{
  "version": "1.2.0",
  "items": [
    {
      "type": "list",
      "title": "What's new",
      "rows": [
        {
          "icon": "sparkles",
          "title": "Polished details",
          "description": "Small UI upgrades throughout the app."
        }
      ]
    },
    {
      "type": "image",
      "url": "https://example.com/preview.jpg",
      "title": "UI preview",
      "description": "A quick look at the redesign."
    },
    {
      "type": "image",
      "asset": "assets/release_notes/archive.png",
      "title": "Journal Archive",
      "description": "Archive entries without deleting them."
    },
    {
      "type": "video",
      "url": "https://example.com/demo.mp4",
      "title": "Feature demo",
      "description": "See the flow in action."
    }
  ]
}
```

Images and videos have either a `url` or an `asset`, decoded as `NoteletMediaSource.network` or
`NoteletMediaSource.asset`.

Icons can't be stored in JSON, so map the `icon` names to `IconData` yourself. Rows whose icon has no mapping use
`noteletFallbackIcon`.

```dart
final versionNotes = NoteletVersionNotes.fromJson(
  jsonDecode(body) as Map<String, Object?>,
  iconResolver: (name) => switch (name) {
    'sparkles' => Icons.auto_awesome,
    'lock' => Icons.lock,
    _ => noteletFallbackIcon,
  },
);
```

Until the notes arrive, pass `NoteletSheet` an empty list. It presents them once they do.

## Note types

`items` is a list of `NoteletVersionNoteItem`s. There are three note types:

* `.list`
* `.image`
* `.video`

### List

Shows a title and a set of rows, where each row has an icon, a title, and a description. Icons are tinted with the
accent color.

This type of note is ideal for showing the user a quick summary of the update.

```dart
.list(
  title: "What's new",
  rows: [
    NoteletListRow(
      icon: Icons.auto_awesome,
      title: 'Polished details',
      description: 'Small UI upgrades throughout the app.',
    ),
  ],
)
```

Any `IconData` works, e.g. `CupertinoIcons.wand_stars` from [`cupertino_ui`](https://pub.dev/packages/cupertino_ui) (with
the [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) font) for an iOS look.

### Image

Loads and shows an image along with a title and description. Great for updates that need a bit more visual context.

The image is shown in a square container, and non-square images are cropped to fill it. It's best to use square images,
or at least keep the main subject in the center.

`image` takes a `NoteletMediaSource`, downloaded from a URL or bundled with your app's assets:

```dart
.image(
  image: .network('https://example.com/preview.jpg'),
  title: 'UI preview',
  description: 'A quick look at the redesign.',
)
```

```dart
.image(
  image: .asset('assets/release_notes/preview.png'),
  title: 'UI preview',
  description: 'A quick look at the redesign.',
)
```

Asset images ship with the app, so they show even when the user is offline. A network image that can't load shows a
placeholder instead. Declare asset images under `flutter: assets:` in your app's `pubspec.yaml`.

### Video

Loads and plays a video along with a title and description. Great for cases when a feature needs a mini-onboarding, or
when you just want to highlight it for the user.

The video plays muted and on a loop while its page is visible, without interrupting audio that's already playing. Same
as with images, it's shown in a square container, so parts of it might be cropped if it has a non-square aspect ratio.

`video` takes a `NoteletMediaSource`, streamed from a URL or bundled with your app's assets:

```dart
.video(
  video: .network('https://example.com/demo.mp4'),
  title: 'Feature demo',
  description: 'See the flow in action.',
)
```

```dart
.video(
  video: .asset('assets/release_notes/demo.mp4'),
  title: 'Feature demo',
  description: 'See the flow in action.',
)
```

Videos play with [`video_player`](https://pub.dev/packages/video_player). A video that can't load or play shows a
placeholder instead. Declare asset videos under `flutter: assets:` in your app's `pubspec.yaml`.

## Sheet dismiss callback

`NoteletSheet` has an optional `onDismiss` callback. `showNoteletSheet()` returns a `Future<bool>` that completes when
the sheet is dismissed, with `true` if a sheet was shown.

> [!TIP]
> Right after the sheet is dismissed is a good time to ask for a review, e.g. with the
> [`in_app_review`](https://pub.dev/packages/in_app_review) package.

```dart
NoteletSheet(
  notes: notes,
  version: .current,
  onDismiss: () => InAppReview.instance.requestReview(),
  child: ...,
)
```

## Additional configuration

Both `NoteletSheet` and `showNoteletSheet()` accept a `NoteletConfiguration` where you can customize button labels, the
accent color and the sheet height.

```dart
NoteletSheet(
  notes: notes,
  version: .current,
  configuration: const NoteletConfiguration(
    nextButtonLabel: 'Continue',
    doneButtonLabel: 'Got it',
    accentColor: Colors.orange,
    sheetHeight: .full,
  ),
  child: ...,
)
```

`accentColor` defaults to your theme's primary color. `sheetHeight` controls the height of the bottom sheet: `.standard`
(the default) covers 85% of the screen and leaves a sliver of the presenting screen visible, and `.full` reaches just
below the status bar. Phones in landscape always use the full height. Large windows, such as iPad, show a centered card
instead, and resizing the window switches between the two in place. Both can be dragged down to dismiss.

### Localizing the labels

Screen readers announce the page indicator, and each image or video along with whether it has loaded. These labels
default to English, like the button labels. To localize them, pass your own:

```dart
NoteletConfiguration(
  nextButtonLabel: 'Weiter',
  doneButtonLabel: 'Fertig',
  pageIndicatorLabel: (page, pageCount) => 'Seite $page von $pageCount',
  imageLabel: 'Bild',
  imageLoadingLabel: 'Bild wird geladen',
  imageFailedLabel: 'Bild konnte nicht geladen werden',
  videoLabel: 'Video',
  videoLoadingLabel: 'Video wird geladen',
  videoFailedLabel: 'Video konnte nicht geladen werden',
)
```

## Latest viewed version storage

When using `version: .current`, Notelet marks the current version as seen by saving it with
[`shared_preferences`](https://pub.dev/packages/shared_preferences) (`UserDefaults` on iOS). The key,
`Notelet.LatestSeenAppVersion`, is the same one the Swift package uses, so on iOS an app that moves from the Swift
package to Flutter keeps its users' "seen" state.

In some cases, you might also want to save it manually. For example, you might not want new users to see the release
notes sheet right after onboarding. In that case, mark the current version as seen when onboarding is done, and they
only see release notes on the next update.

```dart
await const NoteletStorage().markCurrentVersionAsSeen();
```

For debugging purposes, you might also want to reset the storage value:

```dart
await const NoteletStorage().resetSeenVersion();
```

### Sharing the seen version with an App Group

To share the "seen" state with an iOS extension (widget, intent, share extension), pass preferences backed by your App
Group. Add `shared_preferences_foundation` to your dependencies for the options class, and use the same `NoteletStorage`
everywhere:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_foundation/shared_preferences_foundation.dart';

final storage = NoteletStorage(
  preferences: SharedPreferencesAsync(
    options: SharedPreferencesAsyncFoundationOptions(
      suiteName: 'group.com.example.myapp',
    ),
  ),
);

NoteletSheet(
  notes: notes,
  version: .current,
  storage: storage,
  child: ...,
)
```
