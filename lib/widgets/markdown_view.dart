import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'code_block.dart';

/// Отображение Markdown-ответа ИИ.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.text});

  final String text;

  static final Map<String, MarkdownElementBuilder> _builders = {
    'pre': _CodeBlockBuilder(),
  };

  // Таблица стилей создаётся один раз — MarkdownBody не перепарсит текст,
  // если ни текст, ни стили не изменились.
  static MarkdownStyleSheet? _styleSheet;

  static MarkdownStyleSheet _styles(BuildContext context) {
    return _styleSheet ??= () {
      const body = TextStyle(color: AppColors.text, fontSize: 16, height: 1.55);
      return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        listBullet: body,
        strong: const TextStyle(fontWeight: FontWeight.w700),
        em: const TextStyle(fontStyle: FontStyle.italic),
        h1: body.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        h2: body.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        h3: body.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        h4: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        h1Padding: const EdgeInsets.only(top: 8, bottom: 4),
        h2Padding: const EdgeInsets.only(top: 8, bottom: 4),
        h3Padding: const EdgeInsets.only(top: 6, bottom: 2),
        blockSpacing: 12,
        listIndent: 22,
        a: const TextStyle(
          color: Color(0xFF8AB4F8),
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF8AB4F8),
        ),
        code: const TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: ['Menlo', 'Courier'],
          fontSize: 14,
          color: Color(0xFFE6E6E6),
          backgroundColor: AppColors.surface,
        ),
        blockquote: body.copyWith(color: AppColors.textSecondary),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.border, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        tableBorder: TableBorder.all(color: AppColors.border),
        tableHead: body.copyWith(fontWeight: FontWeight.w600),
        tableBody: body,
        tableCellsPadding: const EdgeInsets.all(8),
      );
    }();
  }

  static void _openLink(String text, String? href, String title) {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      styleSheet: _styles(context),
      builders: _builders,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      softLineBreak: true,
      onTapLink: _openLink,
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    String? language;
    final code = element.children?.firstOrNull;
    if (code is md.Element) {
      final cls = code.attributes['class'];
      if (cls != null && cls.startsWith('language-')) {
        language = cls.substring('language-'.length);
      }
    }
    var text = element.textContent;
    if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
    return CodeBlock(code: text, language: language);
  }
}
