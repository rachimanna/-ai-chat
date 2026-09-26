import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

import '../theme/app_theme.dart';

/// Блок кода с подсветкой синтаксиса и кнопкой «Копировать».
class CodeBlock extends StatefulWidget {
  const CodeBlock({super.key, required this.code, this.language});

  final String code;
  final String? language;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  static const _textStyle = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Courier', 'Roboto Mono'],
    fontSize: 13.5,
    height: 1.45,
    color: Color(0xFFABB2BF),
  );

  bool _copied = false;
  late List<TextSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _highlight();
  }

  @override
  void didUpdateWidget(CodeBlock old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code || old.language != widget.language) {
      _spans = _highlight();
    }
  }

  List<TextSpan> _highlight() {
    try {
      final nodes = highlight
          .parse(widget.code, language: widget.language ?? 'plaintext')
          .nodes;
      if (nodes == null) return [TextSpan(text: widget.code)];
      return _convert(nodes);
    } catch (_) {
      return [TextSpan(text: widget.code)];
    }
  }

  List<TextSpan> _convert(List<Node> nodes) {
    final spans = <TextSpan>[];
    for (final node in nodes) {
      final style = node.className == null
          ? null
          : atomOneDarkTheme[node.className!];
      if (node.value != null) {
        spans.add(TextSpan(text: node.value, style: style));
      } else if (node.children != null) {
        spans.add(TextSpan(style: style, children: _convert(node.children!)));
      }
    }
    return spans;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.codeBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.codeHeader,
            padding: const EdgeInsets.only(left: 14, right: 4),
            height: 38,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.language ?? 'код',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _copy,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      key: ValueKey(_copied),
                      size: 16,
                    ),
                  ),
                  label: Text(
                    _copied ? 'Скопировано' : 'Копировать',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: Text.rich(
              TextSpan(style: _textStyle, children: _spans),
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}
