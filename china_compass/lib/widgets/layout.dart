import 'dart:math' as math;

import 'package:flutter/material.dart';

/// From this window width on, the app uses the wide (tablet/desktop) layout:
/// side navigation, cards side by side, centered reading column.
const wideBreakpoint = 900.0;

/// Readable width for text-heavy pages (guides, search, profile).
const readingWidth = 760.0;

/// Max width for overview pages (home, path pages) on very large screens.
const overviewWidth = 1180.0;

bool isWideWindow(BuildContext context) => MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// Side padding that centers content at most [maxWidth] wide inside [available].
EdgeInsets centeredInsets(double available, {double maxWidth = readingWidth, double top = 0, double bottom = 0}) {
  final side = math.max(0.0, (available - maxWidth) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// A scrolling page whose children form a centered column of at most [maxWidth].
class CenteredListView extends StatelessWidget {
  const CenteredListView({
    super.key,
    required this.children,
    this.maxWidth = readingWidth,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final double maxWidth;

  /// Extra padding inside the centered column.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: centeredInsets(constraints.maxWidth, maxWidth: maxWidth) + padding,
          children: children,
        ),
      );
}
