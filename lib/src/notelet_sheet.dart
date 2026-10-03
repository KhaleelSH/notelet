import 'package:material_ui/material_ui.dart';

import 'helpers.dart';
import 'sheet_content.dart';
import 'notelet_sheet_route.dart';
import 'storage.dart';
import 'types.dart';

/// Presents a release-notes sheet over [child], mirroring the SwiftUI
/// `.noteletSheet()` modifier.
///
/// The sheet opens when this widget is first built and whenever [version]
/// changes, as long as [notes] has items for that version. If it has none yet,
/// e.g. while notes load remotely, the sheet opens once new [notes] do. With
/// [NoteletPresentedVersion.current], it only opens if the user hasn't seen the
/// current version yet, and marks it as seen when dismissed. Setting [version]
/// to `null` closes an open sheet without marking it as seen.
///
/// Must be placed below a [Navigator] and [MaterialLocalizations], e.g. inside
/// a [MaterialApp] route.
class NoteletSheet extends StatefulWidget {
  const NoteletSheet({
    super.key,
    required this.notes,
    this.version,
    this.onDismiss,
    this.configuration = const NoteletConfiguration(),
    this.storage = const NoteletStorage(),
    required this.child,
  });

  /// Release notes for every version.
  final List<NoteletVersionNotes> notes;

  /// The version to present, or `null` to present nothing.
  final NoteletPresentedVersion? version;

  /// Called after the sheet is dismissed, e.g. to ask for a review.
  final VoidCallback? onDismiss;

  final NoteletConfiguration configuration;

  /// Backs the "seen version" check used with [NoteletPresentedVersion.current].
  final NoteletStorage storage;

  final Widget child;

  @override
  State<NoteletSheet> createState() => _NoteletSheetState();
}

class _NoteletSheetState extends State<NoteletSheet> {
  Route<void>? _route;
  NoteletPresentedVersion? _presentedVersion;

  /// Whether [NoteletSheet.notes] had no items for [NoteletSheet.version] at
  /// the last sync, so new notes are worth another sync.
  bool _isWaitingForNotes = false;

  /// Increments on every sync so a slow storage read can't act on a stale
  /// [NoteletSheet.version] or [NoteletSheet.notes].
  int _syncCount = 0;

  @override
  void initState() {
    super.initState();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(NoteletSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.version != oldWidget.version ||
        (_isWaitingForNotes && widget.notes != oldWidget.notes)) {
      _scheduleSync();
    }
  }

  @override
  void dispose() {
    final route = _route;

    if (route != null) {
      // Clearing _route keeps _present() from handling this as a dismissal.
      // The navigator can't change while the tree is being finalized, so
      // remove the route after the frame.
      _route = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _removeRoute(route));
    }

    super.dispose();
  }

  /// Routes can't be pushed or popped while building, so sync after the frame.
  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPresentation());
  }

  Future<void> _syncPresentation() async {
    if (!mounted) {
      return;
    }

    final syncCount = ++_syncCount;
    final version = widget.version;
    final storage = widget.storage;
    final items = version == null
        ? const <NoteletVersionNoteItem>[]
        : await _versionNotes(widget.notes, version);
    final shouldPresent =
        version != null &&
        items.isNotEmpty &&
        !await _isAlreadySeen(version, storage);

    if (!mounted || syncCount != _syncCount) {
      return;
    }

    _isWaitingForNotes = version != null && items.isEmpty;
    final route = _route;

    if (version == null || !shouldPresent) {
      // Dismissing completes the route, which runs the usual dismiss handling
      // in _present().
      if (route != null) {
        _removeRoute(route);
      }
      return;
    }

    if (route != null) {
      if (version == _presentedVersion) {
        return;
      }

      // Swap the open sheet for the new version without treating it as a
      // dismissal.
      _route = null;
      _removeRoute(route);
    }

    _present(version, items);
  }

  Future<void> _present(
    NoteletPresentedVersion version,
    List<NoteletVersionNoteItem> items,
  ) async {
    final storage = widget.storage;
    final route = _createRoute(context, items, widget.configuration);
    _route = route;
    _presentedVersion = version;

    await Navigator.of(context).push(route);

    // Swapped for another version's sheet, or removed in dispose().
    if (_route != route) {
      return;
    }

    _route = null;
    _presentedVersion = null;

    // Like the Swift package, check the version at dismissal rather than at
    // presentation, so setting it to null doesn't mark the notes as seen.
    if (widget.version is NoteletCurrentVersion) {
      await storage.markCurrentVersionAsSeen();
    }

    if (mounted) {
      widget.onDismiss?.call();
    }
  }

  static void _removeRoute(Route<void> route) {
    final navigator = route.navigator;

    if (navigator == null || !route.isActive) {
      return;
    }

    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows a release-notes sheet and completes once it's dismissed.
///
/// Returns `false` without showing anything if [notes] has no items for
/// [version], or if [version] is [NoteletPresentedVersion.current] and the
/// user has already seen it. With [NoteletPresentedVersion.current], the
/// version is marked as seen when the sheet is dismissed.
///
/// ```dart
/// final wasShown = await showNoteletSheet(context: context, notes: notes);
/// ```
Future<bool> showNoteletSheet({
  required BuildContext context,
  required List<NoteletVersionNotes> notes,
  NoteletPresentedVersion version = NoteletPresentedVersion.current,
  NoteletConfiguration configuration = const NoteletConfiguration(),
  NoteletStorage storage = const NoteletStorage(),
}) async {
  final items = await _versionNotes(notes, version);

  if (items.isEmpty ||
      await _isAlreadySeen(version, storage) ||
      !context.mounted) {
    return false;
  }

  await Navigator.of(context).push(_createRoute(context, items, configuration));

  if (version is NoteletCurrentVersion) {
    await storage.markCurrentVersionAsSeen();
  }

  return true;
}

/// The items [notes] has for [version].
Future<List<NoteletVersionNoteItem>> _versionNotes(
  List<NoteletVersionNotes> notes,
  NoteletPresentedVersion version,
) async {
  final versionToShow = switch (version) {
    NoteletCurrentVersion() => await getCurrentAppVersion(),
    NoteletSpecificVersion(:final version) => version,
  };

  return getVersionNotes(versionToShow, notes);
}

/// Whether [version] is [NoteletPresentedVersion.current] and the user has
/// already seen it.
Future<bool> _isAlreadySeen(
  NoteletPresentedVersion version,
  NoteletStorage storage,
) async {
  return version is NoteletCurrentVersion &&
      await storage.getLatestSeenAppVersion() == await getCurrentAppVersion();
}

NoteletSheetRoute _createRoute(
  BuildContext context,
  List<NoteletVersionNoteItem> items,
  NoteletConfiguration configuration,
) {
  final navigator = Navigator.of(context);

  return NoteletSheetRoute(
    builder: (context) =>
        NoteletSheetContent(items: items, configuration: configuration),
    sheetHeight: configuration.sheetHeight,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  );
}
