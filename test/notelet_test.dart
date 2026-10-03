import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:notelet/notelet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

const testImageAsset = 'assets/release_notes/archive.png';
const testVideoAsset = 'assets/release_notes/demo.mp4';
const testVideoUrl = 'https://example.com/demo.mp4';

const notes = [
  NoteletVersionNotes(
    version: '1.2.0',
    items: [
      NoteletVersionNoteItem.list(
        title: "What's new",
        rows: [
          NoteletListRow(
            icon: Icons.auto_fix_high,
            title: 'New editor tools',
            description: 'More formatting options with less taps.',
          ),
        ],
      ),
      NoteletVersionNoteItem.list(
        title: 'Privacy',
        rows: [
          NoteletListRow(
            icon: Icons.shield,
            title: 'Privacy update',
            description: 'Sensitive data handling is now stricter.',
          ),
        ],
      ),
    ],
  ),
  NoteletVersionNotes(
    version: '1.1.0',
    items: [
      NoteletVersionNoteItem.image(
        image: NoteletMediaSource.asset(testImageAsset),
        title: 'Journal Archive',
        description: 'Archive entries without deleting them.',
      ),
      NoteletVersionNoteItem.image(
        image: NoteletMediaSource.network('https://example.com/demo.jpg'),
        title: 'Feature demo',
        description: 'See the flow in action.',
      ),
      NoteletVersionNoteItem.video(
        video: NoteletMediaSource.asset(testVideoAsset),
        title: 'Offline tour',
        description: 'Bundled with the app.',
      ),
      NoteletVersionNoteItem.video(
        video: NoteletMediaSource.network(testVideoUrl),
        title: 'Online tour',
        description: 'Streamed when shown.',
      ),
    ],
  ),
  NoteletVersionNotes(
    version: '1.0.1',
    items: [
      NoteletVersionNoteItem.video(
        video: NoteletMediaSource.network('https://example.com/broken.mp4'),
        title: 'Broken tour',
        description: 'Fails to load.',
      ),
    ],
  ),
];

const storage = NoteletStorage();

Widget buildApp({required Widget child, ScrollBehavior? scrollBehavior}) =>
    DefaultAssetBundle(
      bundle: _TestAssetBundle(),
      child: MaterialApp(scrollBehavior: scrollBehavior, home: child),
    );

/// A scroll behavior whose [shouldNotify] only accepts its own type, as
/// [ScrollBehavior] subclasses may declare.
class _StrictScrollBehavior extends MaterialScrollBehavior {
  const _StrictScrollBehavior();

  @override
  bool shouldNotify(covariant _StrictScrollBehavior oldDelegate) => false;
}

/// Serves [testImageAsset] the way an app serves its bundled assets.
class _TestAssetBundle extends CachingAssetBundle {
  /// A transparent 1×1 PNG.
  static final _png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
    0x00, 0x05, 0x00, 0x01, 0x7A, 0x5E, 0xAB, 0x3F, 0x00, 0x00, 0x00, 0x00,
    0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  Future<ByteData> load(String key) async {
    return switch (key) {
      'AssetManifest.bin' => const StandardMessageCodec().encodeMessage({
        testImageAsset: [
          {'asset': testImageAsset},
        ],
      })!,
      testImageAsset => ByteData.sublistView(_png),
      _ => throw FlutterError('Unable to load asset: $key'),
    };
  }
}

void setScreenSize(
  WidgetTester tester,
  Size size, {
  EdgeInsets padding = EdgeInsets.zero,
}) {
  const devicePixelRatio = 3.0;
  final physicalPadding = FakeViewPadding(
    left: padding.left * devicePixelRatio,
    top: padding.top * devicePixelRatio,
    right: padding.right * devicePixelRatio,
    bottom: padding.bottom * devicePixelRatio,
  );
  tester.view
    ..devicePixelRatio = devicePixelRatio
    ..physicalSize = size * devicePixelRatio
    ..padding = physicalPadding
    ..viewPadding = physicalPadding;
  addTearDown(tester.view.reset);
}

/// An iPhone 17 Pro, with its status bar and home indicator.
void setPhoneScreen(WidgetTester tester) {
  setScreenSize(
    tester,
    const Size(402, 874),
    padding: const EdgeInsets.only(top: 62, bottom: 34),
  );
}

/// The sheet's own [Material], which paints its background.
Finder findSheet() => find
    .ancestor(of: find.byType(PageView), matching: find.byType(Material))
    .last;

/// Opens every video instantly, except URLs containing "broken", and records
/// what it was asked to open and play.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final dataSources = <DataSource>[];
  final playing = <int>{};
  final _events = <int, StreamController<VideoEvent>>{};

  /// Whether [play] fails.
  bool failPlay = false;

  /// Breaks a video that already opened, like a stream that drops.
  void failPlayback(int playerId) => _events[playerId]!.addError(
    PlatformException(code: 'failed', message: 'Dropped'),
  );

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = dataSources.length;
    dataSources.add(options.dataSource);
    final events = _events[playerId] = StreamController<VideoEvent>();
    if (options.dataSource.uri?.contains('broken') ?? false) {
      events.addError(PlatformException(code: 'failed', message: 'Broken'));
    } else {
      events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 3),
          size: const Size(720, 720),
        ),
      );
    }
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    playing.remove(playerId);
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> play(int playerId) async {
    if (failPlay) {
      throw PlatformException(code: 'failed', message: "Can't play");
    }

    playing.add(playerId);
  }

  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

late FakeVideoPlayerPlatform videoPlatform;

void main() {
  setUp(() {
    VideoPlayerPlatform.instance = videoPlatform = FakeVideoPlayerPlatform();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    PackageInfo.setMockInitialValues(
      appName: 'Example',
      packageName: 'com.example.app',
      version: '1.2.0',
      buildNumber: '7',
      buildSignature: '',
    );
  });

  group('JSON', () {
    test('decodes list, image and video notes', () {
      final json = jsonDecode('''
            {
              "version": "1.2.0",
              "items": [
                {
                  "type": "list",
                  "title": "What's new",
                  "rows": [{"icon": "sparkles", "title": "Polish", "description": "Details."}]
                },
                {
                  "type": "image",
                  "url": "https://example.com/demo.jpg",
                  "title": "Demo",
                  "description": "The flow."
                },
                {
                  "type": "image",
                  "asset": "assets/archive.png",
                  "title": "Archive",
                  "description": "Old entries."
                },
                {
                  "type": "video",
                  "url": "https://example.com/demo.mp4",
                  "title": "Tour",
                  "description": "Online."
                },
                {
                  "type": "video",
                  "asset": "assets/demo.mp4",
                  "title": "Offline tour",
                  "description": "Bundled."
                }
              ]
            }
          ''') as Map<String, Object?>;

      final versionNotes = NoteletVersionNotes.fromJson(
        json,
        iconResolver: (name) => name == 'sparkles' ? Icons.star : Icons.error,
      );

      expect(versionNotes.version, '1.2.0');

      final [
        list as NoteletListNoteItem,
        network as NoteletImageNoteItem,
        asset as NoteletImageNoteItem,
        networkVideo as NoteletVideoNoteItem,
        assetVideo as NoteletVideoNoteItem,
      ] = versionNotes.items;

      expect(list.title, "What's new");
      expect(list.rows.single.icon, Icons.star);
      expect(list.rows.single.title, 'Polish');
      expect(
        network.image,
        const NoteletMediaSource.network('https://example.com/demo.jpg'),
      );
      expect(network.title, 'Demo');
      expect(asset.image, const NoteletMediaSource.asset('assets/archive.png'));
      expect(asset.description, 'Old entries.');
      expect(
        networkVideo.video,
        const NoteletMediaSource.network('https://example.com/demo.mp4'),
      );
      expect(networkVideo.title, 'Tour');
      expect(
        assetVideo.video,
        const NoteletMediaSource.asset('assets/demo.mp4'),
      );
      expect(assetVideo.description, 'Bundled.');
    });

    test('falls back to a default icon without a resolver', () {
      final row = NoteletListRow.fromJson({
        'icon': 'sparkles',
        'title': 'Polish',
        'description': 'Details.',
      });

      expect(row.icon, noteletFallbackIcon);
    });

    test('rejects unknown note types', () {
      expect(
        () => NoteletVersionNoteItem.fromJson({'type': 'poll'}),
        throwsFormatException,
      );
    });

    test('rejects media without exactly one of url and asset', () {
      for (final type in ['image', 'video']) {
        for (final source in [
          <String, Object?>{},
          {'url': 'https://example.com/a', 'asset': 'assets/a'},
        ]) {
          expect(
            () => NoteletVersionNoteItem.fromJson({
              'type': type,
              'title': 'A',
              'description': 'B',
              ...source,
            }),
            throwsFormatException,
          );
        }
      }
    });
  });

  group('NoteletPresentedVersion', () {
    test('compares specific versions by value', () {
      expect(
        const NoteletPresentedVersion.v('1.0'),
        const NoteletPresentedVersion.v('1.0'),
      );
      expect(
        const NoteletPresentedVersion.v('1.0'),
        isNot(const NoteletPresentedVersion.v('1.1')),
      );
      expect(
        NoteletPresentedVersion.current,
        isNot(const NoteletPresentedVersion.v('1.2.0')),
      );
    });
  });

  group('NoteletStorage', () {
    test('marks, reads and resets the seen version', () async {
      expect(await storage.getLatestSeenAppVersion(), isNull);

      await storage.markCurrentVersionAsSeen();
      expect(await storage.getLatestSeenAppVersion(), '1.2.0');

      await storage.resetSeenVersion();
      expect(await storage.getLatestSeenAppVersion(), isNull);
    });
  });

  group('showNoteletSheet', () {
    Future<BuildContext> pumpApp(WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const Scaffold();
            },
          ),
        ),
      );
      return context;
    }

    Future<Future<bool>> show(
      WidgetTester tester, {
      NoteletPresentedVersion version = NoteletPresentedVersion.current,
      NoteletConfiguration configuration = const NoteletConfiguration(),
    }) async {
      final context = await pumpApp(tester);
      // Images decode outside the test's fake clock, so load the asset up
      // front; a loading spinner would keep the sheet from settling.
      await tester.runAsync(
        () => precacheImage(const AssetImage(testImageAsset), context),
      );

      final result = showNoteletSheet(
        context: context,
        notes: notes,
        version: version,
        configuration: configuration,
      );
      await tester.pumpAndSettle();

      return result;
    }

    Future<void> showPage(
      WidgetTester tester,
      int page, {
      required NoteletPresentedVersion version,
      NoteletConfiguration configuration = const NoteletConfiguration(),
    }) async {
      await show(tester, version: version, configuration: configuration);
      for (var i = 0; i < page; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('pages through notes and marks the current version as seen', (
      tester,
    ) async {
      final result = await show(tester);

      expect(find.text("What's new"), findsOneWidget);
      expect(find.text('New editor tools'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 1 of 2'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Privacy update'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 2 of 2'), findsOneWidget);
      expect(await storage.getLatestSeenAppVersion(), isNull);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Privacy update'), findsNothing);
      expect(await result, isTrue);
      expect(await storage.getLatestSeenAppVersion(), '1.2.0');
    });

    testWidgets('skips the current version once it has been seen', (
      tester,
    ) async {
      await storage.markCurrentVersionAsSeen();

      final result = await show(tester);

      expect(find.text("What's new"), findsNothing);
      expect(await result, isFalse);
    });

    testWidgets('shows a specific version without marking it seen', (
      tester,
    ) async {
      final result = await show(
        tester,
        version: const NoteletPresentedVersion.v('1.2.0'),
      );

      expect(find.text("What's new"), findsOneWidget);

      // Dismiss by tapping the barrier above the sheet.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
      expect(await storage.getLatestSeenAppVersion(), isNull);
    });

    testWidgets('shows a specific version even after it was seen', (
      tester,
    ) async {
      await storage.markCurrentVersionAsSeen();

      await show(tester, version: const NoteletPresentedVersion.v('1.2.0'));

      expect(find.text("What's new"), findsOneWidget);
    });

    testWidgets('is a bottom sheet on phones that drags down to dismiss', (
      tester,
    ) async {
      setScreenSize(tester, const Size(402, 874));
      final result = await show(tester);

      final sheetSize = tester.getSize(find.byType(PageView));
      expect(sheetSize.width, 402);
      expect(sheetSize.height, moreOrLessEquals((874 - 8) * 0.85));

      // A short, slow drag springs back.
      await tester.timedDrag(
        find.text("What's new"),
        const Offset(0, 60),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();

      expect(find.text("What's new"), findsOneWidget);

      await tester.timedDrag(
        find.text("What's new"),
        const Offset(0, 500),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();

      expect(find.text("What's new"), findsNothing);
      expect(await result, isTrue);
      expect(await storage.getLatestSeenAppVersion(), '1.2.0');
    });

    testWidgets('stretches past fully open without leaving the bottom edge', (
      tester,
    ) async {
      setPhoneScreen(tester);
      await show(tester);

      final restingTop = tester.getRect(findSheet()).top;
      // One large move, like a fast drag, then a few more.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text("What's new")),
      );
      await gesture.moveBy(const Offset(0, -40));
      await gesture.moveBy(const Offset(0, -60));
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, -40));
      }
      await tester.pump();

      final stretched = tester.getRect(findSheet());
      expect(stretched.top, lessThan(restingTop));
      expect(stretched.top, greaterThan(restingTop - 12));
      expect(stretched.bottom, greaterThanOrEqualTo(874));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.getRect(findSheet()).top, restingTop);
    });

    testWidgets("doesn't scroll pages whose content fits", (tester) async {
      // An iPhone 17 Pro Max: media pages overflow the iPhone 17 Pro's sheet by
      // a few points, but fit here.
      setScreenSize(
        tester,
        const Size(440, 956),
        padding: const EdgeInsets.only(top: 62, bottom: 34),
      );
      await show(tester, version: const NoteletPresentedVersion.v('1.1.0'));

      final pageScrollables = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      expect(pageScrollables, findsWidgets);

      for (final element in pageScrollables.evaluate()) {
        final position = (element as StatefulElement).state as ScrollableState;
        expect(position.position.maxScrollExtent, 0);
      }
    });

    testWidgets('is a full-height bottom sheet on phones in landscape', (
      tester,
    ) async {
      // An iPhone 17 Pro in landscape, wide enough for the card.
      setScreenSize(
        tester,
        const Size(874, 402),
        padding: const EdgeInsets.fromLTRB(62, 0, 62, 20),
      );
      await show(tester);

      // Full height, with the content clear of the notch on either side.
      expect(
        tester.getRect(find.byType(PageView)),
        const Rect.fromLTRB(62, 8, 874 - 62, 402),
      );
    });

    testWidgets('is a centered card on tablets', (tester) async {
      setScreenSize(tester, const Size(1024, 1366));
      await show(tester);

      final sheet = tester.getRect(find.byType(PageView));
      expect(sheet.size, const Size(580, 650));
      expect(sheet.center, const Offset(512, 683));

      // An iPad mini in landscape is still tall enough for a card.
      setScreenSize(tester, const Size(1133, 744));
      await tester.pumpAndSettle();

      final landscapeSheet = tester.getRect(find.byType(PageView));
      expect(landscapeSheet.size, const Size(580, 744 - 2 * 64));
      expect(landscapeSheet.center, const Offset(1133 / 2, 744 / 2));
    });

    testWidgets('shows nothing for a version without notes', (tester) async {
      final result = await show(
        tester,
        version: const NoteletPresentedVersion.v('9.9.9'),
      );

      expect(find.byType(PageView), findsNothing);
      expect(await result, isFalse);
    });

    testWidgets('loads asset images and describes their load state', (
      tester,
    ) async {
      final context = await pumpApp(tester);
      showNoteletSheet(
        context: context,
        notes: notes,
        version: const NoteletPresentedVersion.v('1.1.0'),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.bySemanticsLabel(
          'Loading image. Journal Archive. '
          'Archive entries without deleting them.',
        ),
        findsOneWidget,
      );

      // Images load and decode outside the test's fake clock, so give them
      // real time between frames.
      final loaded = find.bySemanticsLabel(
        'Image. Journal Archive. Archive entries without deleting them.',
      );
      for (var i = 0; i < 20 && loaded.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(loaded, findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // flutter_test answers every HTTP request with a 400.
      expect(
        find.bySemanticsLabel(
          'Image failed to load. Feature demo. See the flow in action.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('plays asset and network videos while their page is visible', (
      tester,
    ) async {
      await show(tester, version: const NoteletPresentedVersion.v('1.1.0'));
      for (var page = 0; page < 2; page++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      final assetVideo = videoPlatform.dataSources.indexWhere(
        (source) =>
            source.sourceType == DataSourceType.asset &&
            source.asset == testVideoAsset,
      );
      final networkVideo = videoPlatform.dataSources.indexWhere(
        (source) =>
            source.sourceType == DataSourceType.network &&
            source.uri == testVideoUrl,
      );

      expect(assetVideo, isNot(-1));
      expect(networkVideo, isNot(-1));
      expect(
        find.bySemanticsLabel('Video. Offline tour. Bundled with the app.'),
        findsOneWidget,
      );
      expect(videoPlatform.playing, {assetVideo});

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Video. Online tour. Streamed when shown.'),
        findsOneWidget,
      );
      expect(videoPlatform.playing, {networkVideo});
    });

    testWidgets('describes videos that fail to load', (tester) async {
      await show(tester, version: const NoteletPresentedVersion.v('1.0.1'));

      expect(
        find.bySemanticsLabel(
          'Video failed to load. Broken tour. Fails to load.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('describes videos that break after loading', (tester) async {
      await showPage(
        tester,
        2,
        version: const NoteletPresentedVersion.v('1.1.0'),
      );
      final assetVideo = videoPlatform.dataSources.indexWhere(
        (source) => source.asset == testVideoAsset,
      );

      videoPlatform.failPlayback(assetVideo);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          'Video failed to load. Offline tour. Bundled with the app.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('describes videos that fail to play', (tester) async {
      videoPlatform.failPlay = true;

      await showPage(
        tester,
        2,
        version: const NoteletPresentedVersion.v('1.1.0'),
      );

      expect(
        find.bySemanticsLabel(
          'Video failed to load. Offline tour. Bundled with the app.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses the configured accessibility labels', (tester) async {
      final configuration = NoteletConfiguration(
        pageIndicatorLabel: (page, pageCount) => 'Seite $page von $pageCount',
        imageLabel: 'Bild',
        videoLabel: 'Film',
      );

      await show(
        tester,
        version: const NoteletPresentedVersion.v('1.1.0'),
        configuration: configuration,
      );

      expect(find.bySemanticsLabel('Seite 1 von 4'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Bild. Journal Archive. Archive entries without deleting them.',
        ),
        findsOneWidget,
      );

      for (var page = 0; page < 2; page++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.bySemanticsLabel('Seite 3 von 4'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Film. Offline tour. Bundled with the app.'),
        findsOneWidget,
      );
    });

    testWidgets('rebuilds mid-drag under a scroll behavior that only '
        'compares its own type', (tester) async {
      setPhoneScreen(tester);
      await tester.pumpWidget(
        buildApp(
          scrollBehavior: const _StrictScrollBehavior(),
          child: const NoteletSheet(
            notes: notes,
            version: NoteletPresentedVersion.current,
            child: Scaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text("What's new")),
      );
      for (var i = 0; i < 3; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }
      // Resizing rebuilds the sheet, and with it the scroll behavior that the
      // drag put in place.
      setScreenSize(tester, const Size(402, 800));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the same route animation', (tester) async {
      await show(tester);

      final route = ModalRoute.of(tester.element(find.byType(PageView)))!;
      expect(route.animation, same(route.animation));
    });
  });

  group('NoteletSheet', () {
    testWidgets('presents unseen current notes on first build', (tester) async {
      var dismissCount = 0;

      await tester.pumpWidget(
        buildApp(
          child: NoteletSheet(
            notes: notes,
            version: NoteletPresentedVersion.current,
            onDismiss: () => dismissCount++,
            child: const Scaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("What's new"), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Privacy update'), findsNothing);
      expect(dismissCount, 1);
      expect(await storage.getLatestSeenAppVersion(), '1.2.0');
    });

    testWidgets('presents when the version changes and closes on null', (
      tester,
    ) async {
      final version = ValueNotifier<NoteletPresentedVersion?>(null);
      var dismissCount = 0;

      await tester.pumpWidget(
        buildApp(
          child: ValueListenableBuilder(
            valueListenable: version,
            builder: (context, version, _) => NoteletSheet(
              notes: notes,
              version: version,
              onDismiss: () => dismissCount++,
              configuration: const NoteletConfiguration(
                nextButtonLabel: 'Continue',
                doneButtonLabel: 'Got it',
              ),
              child: const Scaffold(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);

      version.value = const NoteletPresentedVersion.v('1.2.0');
      await tester.pumpAndSettle();

      expect(find.text("What's new"), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      version.value = null;
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(dismissCount, 1);
    });

    testWidgets('presents notes that arrive after the first build', (
      tester,
    ) async {
      final remoteNotes = ValueNotifier<List<NoteletVersionNotes>>(const []);

      await tester.pumpWidget(
        buildApp(
          child: ValueListenableBuilder(
            valueListenable: remoteNotes,
            builder: (context, value, _) => NoteletSheet(
              notes: value,
              version: NoteletPresentedVersion.current,
              child: const Scaffold(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);

      remoteNotes.value = notes;
      await tester.pumpAndSettle();

      expect(find.text("What's new"), findsOneWidget);
    });

    testWidgets("doesn't mark the current version as seen when closed on "
        'null', (tester) async {
      final version = ValueNotifier<NoteletPresentedVersion?>(
        NoteletPresentedVersion.current,
      );
      var dismissCount = 0;

      await tester.pumpWidget(
        buildApp(
          child: ValueListenableBuilder(
            valueListenable: version,
            builder: (context, version, _) => NoteletSheet(
              notes: notes,
              version: version,
              onDismiss: () => dismissCount++,
              child: const Scaffold(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("What's new"), findsOneWidget);

      version.value = null;
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(dismissCount, 1);
      expect(await storage.getLatestSeenAppVersion(), isNull);

      version.value = NoteletPresentedVersion.current;
      await tester.pumpAndSettle();

      expect(find.text("What's new"), findsOneWidget);
    });

    testWidgets('closes its sheet when removed', (tester) async {
      final showsSheet = ValueNotifier(true);
      var dismissCount = 0;

      await tester.pumpWidget(
        buildApp(
          child: ValueListenableBuilder(
            valueListenable: showsSheet,
            builder: (context, showsSheet, _) => showsSheet
                ? NoteletSheet(
                    notes: notes,
                    version: NoteletPresentedVersion.current,
                    onDismiss: () => dismissCount++,
                    child: const Scaffold(),
                  )
                : const Scaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("What's new"), findsOneWidget);

      showsSheet.value = false;
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(dismissCount, 0);
      expect(await storage.getLatestSeenAppVersion(), isNull);
    });
  });
}
