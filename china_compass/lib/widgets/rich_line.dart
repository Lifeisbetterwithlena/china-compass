import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders the tiny inline markup used in content files: **bold** and [label](https://url).
class RichLine extends StatefulWidget {
  const RichLine(this.source, {super.key, this.style});

  final String source;
  final TextStyle? style;

  @override
  State<RichLine> createState() => _RichLineState();
}

class _RichLineState extends State<RichLine> {
  static final _token = RegExp(r'\*\*(.+?)\*\*|\[(.+?)\]\((https?://[^)\s]+)\)');
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _spans(Color linkColor) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _token.allMatches(widget.source)) {
      if (m.start > last) spans.add(TextSpan(text: widget.source.substring(last, m.start)));
      if (m[1] != null) {
        spans.add(TextSpan(text: m[1], style: const TextStyle(fontWeight: FontWeight.w700)));
      } else {
        final url = Uri.parse(m[3]!);
        final recognizer = TapGestureRecognizer()
          ..onTap = () => launchUrl(url, mode: LaunchMode.externalApplication);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: m[2],
          style: TextStyle(color: linkColor, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
          recognizer: recognizer,
        ));
      }
      last = m.end;
    }
    if (last < widget.source.length) spans.add(TextSpan(text: widget.source.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    return Text.rich(TextSpan(style: base, children: _spans(Theme.of(context).colorScheme.tertiary)));
  }
}
