import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// Crisp vector flags drawn in code, so they look identical on every platform
/// (flag emoji don't render on Windows and vary between devices).
class Flag extends StatelessWidget {
  const Flag(this.kind, {super.key, this.width = 28});

  final FlagKind kind;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 2 / 3;
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.12), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: switch (kind) {
            FlagKind.uk => _UnionJackPainter(),
            FlagKind.germany => _GermanyPainter(),
            FlagKind.spain => _SpainPainter(),
          },
        ),
      ),
    );
  }
}

class _GermanyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / 3;
    const colors = [Color(0xFF000000), Color(0xFFDD0000), Color(0xFFFFCE00)];
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(Rect.fromLTWH(0, h * i, size.width, h + 0.5), Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simplified Spanish flag (red–yellow–red, 1:2:1), without the coat of arms.
class _SpainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final q = size.height / 4;
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0xFFAA151B))
      ..drawRect(Rect.fromLTWH(0, q, size.width, q * 2), Paint()..color = const Color(0xFFF1BF00));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnionJackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final u = h / 30; // official proportions are expressed in 1/30 of the height
    const blue = Color(0xFF012169), red = Color(0xFFC8102E);

    canvas.drawRect(Offset.zero & size, Paint()..color = blue);

    final diag = Paint()..strokeWidth = 6 * u;
    canvas
      ..drawLine(Offset.zero, Offset(w, h), diag..color = Colors.white)
      ..drawLine(Offset(w, 0), Offset(0, h), diag);
    final redDiag = Paint()
      ..strokeWidth = 2 * u
      ..color = red;
    canvas
      ..drawLine(Offset.zero, Offset(w, h), redDiag)
      ..drawLine(Offset(w, 0), Offset(0, h), redDiag);

    final white = Paint()..color = Colors.white;
    canvas
      ..drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w, height: 10 * u), white)
      ..drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: 10 * u, height: h), white);
    final redCross = Paint()..color = red;
    canvas
      ..drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w, height: 6 * u), redCross)
      ..drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: 6 * u, height: h), redCross);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
