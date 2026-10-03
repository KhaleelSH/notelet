import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import 'types.dart';
import 'vendor/scroll_drag_detector.dart';

/// The centered card's geometry; the compact width breakpoint derives from
/// what it needs to fit.
const _kCardWidth = 580.0;
const _kCardHeight = 650.0;
const _kCardHorizontalMargin = 40.0;

/// Windows shorter than this, such as phones in landscape, get a full-height
/// bottom sheet, as a card or a partial-height sheet would leave little room
/// for the notes. iOS sheets fill compact-height screens too, and Material's
/// compact window height class ends here.
const _kCompactHeight = 480.0;

bool _isCompactHeight(Size size) => size.height < _kCompactHeight;

/// Whether the sheet is a bottom sheet rather than a centered card.
bool isNoteletSheetCompact(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width < _kCardWidth + 2 * _kCardHorizontalMargin ||
      _isCompactHeight(size);
}

/// Presents release notes as a draggable bottom sheet below the status bar in
/// compact windows, and as a centered card in large ones such as iPad. The
/// route re-reads the size, so resizing the window morphs the presentation in
/// place.
class NoteletSheetRoute extends PopupRoute<void> {
  NoteletSheetRoute({
    required this.builder,
    required this.sheetHeight,
    required this.capturedThemes,
    required this._barrierLabel,
  });

  final WidgetBuilder builder;
  final NoteletSheetHeight sheetHeight;
  final CapturedThemes capturedThemes;

  /// A smooth (bounce-free) iOS-feel spring. The drag writes straight into the
  /// route's controller, so drag and transition are one continuous motion: a
  /// release hands the finger's velocity to this spring.
  static final SpringDescription _spring =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 350),
      );

  /// How hard the sheet resists being dragged past fully open.
  static const _overshootResistance = 5000.0;

  /// Release velocity that dismisses regardless of position, matching
  /// Material's bottom sheet.
  static const _dismissFlingVelocity = 700.0;

  final String _barrierLabel;

  /// Lets touches through to the page behind while the sheet animates out.
  final ValueNotifier<bool> _popped = ValueNotifier(false);

  /// Whether an upward drag may still pull the sheet toward fully open —
  /// judged by where the running animation is heading, so settling does not
  /// flap it. A notifier, so only its flips rebuild the drag detector.
  final ValueNotifier<bool> _scrollableCanMoveBack = ValueNotifier(false);

  /// Finger velocity at release in screen-heights per second, positive
  /// downward, for [createSimulation] to carry into the dismissal spring.
  double? _dragEndVelocity;

  /// Measured height of the visible sheet, for the release threshold.
  double _sheetHeight = 0;

  /// Created once, as widgets given an animation resubscribe whenever it's a
  /// different object.
  _ClampedAnimation? _clampedAnimation;

  /// Dims the screen as much as a native iOS sheet, like Cupertino's
  /// kCupertinoModalBarrierColor. The navigator rebuilds the barrier when its
  /// theme changes.
  @override
  Color? get barrierColor => switch (Theme.of(navigator!.context).brightness) {
    Brightness.light => const Color(0x33000000),
    Brightness.dark => const Color(0x7A000000),
  };

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => _barrierLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  /// Unbounded, so a drag can rubber-band past fully open and springs may
  /// overshoot; everything reading route progress gets the clamped [animation].
  @override
  AnimationController createAnimationController() =>
      AnimationController.unbounded(debugLabel: debugLabel, vsync: navigator!);

  @override
  Animation<double>? get animation => switch (super.animation) {
    null => null,
    final parent => _clampedAnimation ??= _ClampedAnimation(parent),
  };

  @override
  Simulation createSimulation({required bool forward}) {
    final releaseVelocity = _dragEndVelocity ?? 0;
    _dragEndVelocity = null;
    final end = forward ? 1.0 : 0.0;
    _scrollableCanMoveBack.value = end < 1.0;
    return SpringSimulation(
      _spring,
      controller?.value ?? (forward ? 0.0 : 1.0),
      end,
      -releaseVelocity,
      snapToEnd: true,
    );
  }

  @override
  bool didPop(void result) {
    _popped.value = true;
    return super.didPop(result);
  }

  @override
  void dispose() {
    _popped.dispose();
    _scrollableCanMoveBack.dispose();
    super.dispose();
  }

  @override
  Widget buildModalBarrier() {
    final color = animation!.drive(
      ColorTween(
        begin: barrierColor!.withValues(alpha: 0),
        end: barrierColor,
      ).chain(CurveTween(curve: barrierCurve)),
    );
    return ValueListenableBuilder<bool>(
      valueListenable: _popped,
      builder: (context, popped, child) =>
          IgnorePointer(ignoring: popped, child: child),
      child: AnimatedModalBarrier(
        color: color,
        semanticsLabel: barrierLabel,
        barrierSemanticsDismissible: semanticsDismissible,
      ),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return capturedThemes.wrap(
      ValueListenableBuilder<bool>(
        valueListenable: _scrollableCanMoveBack,
        builder: (context, canMoveBack, child) => ScrollDragDetector(
          scrollableCanMoveBack: canMoveBack,
          onVerticalDragUpdate: (details, wouldScroll) =>
              _handleDragUpdate(details.delta.dy / screenHeight, wouldScroll),
          onVerticalDragEnd: (details, willScroll) => _handleDragEnd(
            details.velocity.pixelsPerSecond.dy / screenHeight,
            screenHeight,
            willScroll,
          ),
          onVerticalDragCancel: _handleDragCancel,
          child: child!,
        ),
        child: _NoteletSheetLayout(route: this),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // The raw controller, not the clamped animation: overshoot must render.
    return AnimatedBuilder(
      animation: controller!,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (1 - controller!.value) * screenHeight),
        child: child,
      ),
      child: child,
    );
  }

  void _handleDragUpdate(double delta, bool wouldScroll) {
    if (_popped.value) return;
    // Resistance applies to the whole drag past fully open, not per event, so
    // a single large event (a fast drag) can't skip it.
    final target = _undoOvershootResistance(controller!.value) - delta;
    final double value;
    if (target <= 1.0) {
      value = target;
    } else if (wouldScroll) {
      // A hand-off frame must not push the sheet past fully open.
      value = 1.0;
    } else {
      value = 1.0 + _applyOvershootResistance(target - 1.0);
    }
    controller!.value = value;
    _scrollableCanMoveBack.value = value < 1.0;
  }

  /// How far past fully open the sheet moves for a [drag] past it, both in
  /// screen heights: the resistance grows with the distance already
  /// stretched.
  double _applyOvershootResistance(double drag) =>
      (math.sqrt(1 + 2 * _overshootResistance * drag) - 1) /
      _overshootResistance;

  /// Where the finger would have taken the sheet without resistance.
  double _undoOvershootResistance(double value) {
    final overshoot = value - 1.0;
    if (overshoot <= 0) return value;
    return 1.0 + overshoot + _overshootResistance * overshoot * overshoot / 2;
  }

  void _handleDragEnd(
    double relativeVelocity,
    double screenHeight,
    bool willScroll,
  ) {
    if (_popped.value) return;
    final current = controller!.value;
    if (willScroll || current > 1.0) {
      // The gesture carries on as a scroll inside the sheet, or the sheet is
      // stretched past open: spring home.
      _springTo(1, velocity: 0);
      return;
    }
    final absoluteVelocity = relativeVelocity * screenHeight;
    final bool dismiss;
    if (absoluteVelocity.abs() >= _dismissFlingVelocity) {
      // Any deliberate motion at release continues in its direction.
      dismiss = absoluteVelocity > 0;
    } else {
      dismiss = (1 - current) * screenHeight > _sheetHeight / 2;
    }
    if (dismiss) {
      _dragEndVelocity = relativeVelocity;
      navigator?.pop();
    } else {
      _springTo(1, velocity: -relativeVelocity);
    }
  }

  void _handleDragCancel() {
    if (_popped.value) return;
    _springTo(1, velocity: 0);
  }

  void _springTo(double target, {required double velocity}) {
    _scrollableCanMoveBack.value = target < 1.0;
    controller!.animateWith(
      SpringSimulation(
        _spring,
        controller!.value,
        target,
        velocity,
        snapToEnd: true,
      ),
    );
  }
}

class _NoteletSheetLayout extends StatelessWidget {
  const _NoteletSheetLayout({required this.route});

  final NoteletSheetRoute route;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = isNoteletSheetCompact(context);
    final isStandardHeight =
        isCompact &&
        !_isCompactHeight(size) &&
        route.sheetHeight == NoteletSheetHeight.standard;
    // The bottom sheet's background continues below the screen, so a stretch
    // or spring past fully open never lifts it off the bottom edge.
    final skirt = isCompact ? size.height / 4 : 0.0;

    // Both modes build the same tree shape so a resize only changes
    // configuration and the sheet's content keeps its state.
    return Align(
      alignment: isCompact ? Alignment.bottomCenter : Alignment.center,
      child: Padding(
        padding: isCompact
            ? EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 8)
            : const EdgeInsets.symmetric(
                horizontal: _kCardHorizontalMargin,
                vertical: 64,
              ),
        child: ConstrainedBox(
          constraints: isCompact
              ? const BoxConstraints.expand()
              : const BoxConstraints(
                  maxWidth: _kCardWidth,
                  maxHeight: _kCardHeight,
                ),
          child: FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            // The standard height leaves a sliver of the presenting screen
            // visible.
            heightFactor: isStandardHeight ? 0.85 : 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                route._sheetHeight = constraints.maxHeight;
                return OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: constraints.maxHeight + skirt,
                  maxHeight: constraints.maxHeight + skirt,
                  child: Material(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: isCompact
                          ? const BorderRadius.vertical(
                              top: Radius.circular(32),
                            )
                          : BorderRadius.circular(32),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: skirt),
                      // The sheet reaches the bottom and side edges only when
                      // compact, and never the top one; the content must not
                      // inset for system UI that is not there, but must clear
                      // a notch in landscape.
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        removeBottom: !isCompact,
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: Builder(builder: route.builder),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  /// [NoteletSheetRoute]'s controller is unbounded; everything expecting 0..1
  /// route progress (the barrier fade) reads this instead.
  _ClampedAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);
}
