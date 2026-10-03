import 'package:material_ui/material_ui.dart';

import 'note_item_view.dart';
import 'notelet_sheet_route.dart';
import 'types.dart';

/// Paged release notes with a page indicator and a Next/Done button.
class NoteletSheetContent extends StatefulWidget {
  const NoteletSheetContent({
    super.key,
    required this.items,
    required this.configuration,
  });

  final List<NoteletVersionNoteItem> items;
  final NoteletConfiguration configuration;

  @override
  State<NoteletSheetContent> createState() => _NoteletSheetContentState();
}

class _NoteletSheetContentState extends State<NoteletSheetContent> {
  final _pageController = PageController();
  int _currentPage = 0;

  bool get _isOnLastPage => _currentPage >= widget.items.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onButtonPressed() {
    if (_isOnLastPage) {
      Navigator.of(context).pop();
      return;
    }

    _springToNextPage();
  }

  /// The Next button's last spring, so a tap while it runs can carry its
  /// velocity into the next one.
  BallisticScrollActivity? _nextPageActivity;

  /// Moves to the next page on the spring that settles swipes, so taps and
  /// swipes move alike, close to SwiftUI's `.smooth` in the Swift package.
  void _springToNextPage() {
    // Page view positions run their own scroll activities.
    final position =
        _pageController.position as ScrollPositionWithSingleContext;
    final physics = position.physics;
    final target =
        (_pageController.page!.round() + 1) * position.viewportDimension;

    final activity = BallisticScrollActivity(
      position,
      ScrollSpringSimulation(
        physics.spring,
        position.pixels,
        target,
        // Zero once that spring has finished or a drag interrupted it, as the
        // position then disposes it.
        _nextPageActivity?.velocity ?? 0,
        tolerance: physics.toleranceFor(position),
      ),
      position.context.vsync,
      // Like animateTo(), ignore taps on the pages while moving.
      true,
    );
    _nextPageActivity = activity;
    position.beginActivity(activity);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = isNoteletSheetCompact(context);

    // Keeps the app's snack bars out of the sheet. The app's ScaffoldMessenger
    // shows them on every Scaffold that isn't nested in another one, which
    // includes this one.
    return ScaffoldMessenger(
      child: Scaffold(
        // NoteletSheetRoute paints the sheet's background.
        backgroundColor: Colors.transparent,
        // Lets pages scroll under the bottom bar, and adds the bar's height to
        // their bottom padding.
        extendBody: true,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              // Keeps the neighbouring pages built, so the next image or video
              // starts loading before it's swiped to.
              allowImplicitScrolling: true,
              itemCount: widget.items.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) => _NotePage(
                item: widget.items[index],
                isCurrent: index == _currentPage,
                configuration: widget.configuration,
              ),
            ),
            // Both the bottom sheet and the centered card drag down to dismiss.
            const Positioned(
              top: 5,
              left: 0,
              right: 0,
              child: Center(child: _DragIndicator()),
            ),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          pageCount: widget.items.length,
          currentPage: _currentPage,
          pageIndicatorLabel: widget.configuration.pageIndicatorLabel(
            _currentPage + 1,
            widget.items.length,
          ),
          buttonLabel: _isOnLastPage
              ? widget.configuration.doneButtonLabel
              : widget.configuration.nextButtonLabel,
          accentColor: widget.configuration.accentColor,
          isCompact: isCompact,
          onButtonPressed: _onButtonPressed,
        ),
      ),
    );
  }
}

class _NotePage extends StatefulWidget {
  const _NotePage({
    required this.item,
    required this.isCurrent,
    required this.configuration,
  });

  final NoteletVersionNoteItem item;
  final bool isCurrent;
  final NoteletConfiguration configuration;

  @override
  State<_NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<_NotePage>
    with AutomaticKeepAliveClientMixin {
  // Keep visited pages alive so images and videos don't reload when swiping
  // back to them.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SingleChildScrollView(
      // Every page has its own scroll view, so none can share the primary
      // scroll controller.
      primary: false,
      // Just clears the bottom bar. Note items end with their own padding, so
      // anything extra would make pages scroll even when their content fits.
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: NoteItemView(
        item: widget.item,
        isCurrent: widget.isCurrent,
        configuration: widget.configuration,
      ),
    );
  }
}

class _DragIndicator extends StatelessWidget {
  const _DragIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurfaceVariant
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.pageCount,
    required this.currentPage,
    required this.pageIndicatorLabel,
    required this.buttonLabel,
    required this.accentColor,
    required this.isCompact,
    required this.onButtonPressed,
  });

  final int pageCount;
  final int currentPage;
  final String pageIndicatorLabel;
  final String buttonLabel;
  final Color? accentColor;
  final bool isCompact;
  final VoidCallback onButtonPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = accentColor ?? theme.colorScheme.primary;
    final buttonForegroundColor = accentColor == null
        ? theme.colorScheme.onPrimary
        : switch (ThemeData.estimateBrightnessForColor(buttonColor)) {
            Brightness.dark => Colors.white,
            Brightness.light => Colors.black,
          };

    // The sheet's own background color.
    final sheetColor = theme.canvasColor;

    // Fades out pages that scroll under the bar, like a soft scroll edge.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.5],
          colors: [
            sheetColor.withValues(alpha: 0),
            sheetColor.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        // The centered card has no system UI below it, so keep the button
        // clear of its rounded corners.
        minimum: EdgeInsets.only(bottom: isCompact ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            if (pageCount > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _PageIndicator(
                  pageCount: pageCount,
                  currentPage: currentPage,
                  label: pageIndicatorLabel,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FilledButton(
                onPressed: onButtonPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: buttonForegroundColor,
                  minimumSize: const Size.fromHeight(64),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.pageCount,
    required this.currentPage,
    required this.label,
  });

  final int pageCount;
  final int currentPage;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.canvasColor,
          borderRadius: BorderRadius.circular(9.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              for (var index = 0; index < pageCount; index++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: index == currentPage ? 14 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: index == currentPage
                        ? colorScheme.onSurface.withValues(alpha: 0.35)
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
