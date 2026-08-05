/// Expansion of an HTML table into a merged-cell-free 2D matrix.
///
/// DOM-only parsing (package:html). The wiki markup must never be parsed with
/// regular expressions; this module is the single entry point for table
/// structure.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:html/dom.dart';
/// A footnote reference found inside a cell (`<a class="note_super"
/// data-tooltip-content="...">*N</a>`).
class FootnoteRef {
  final String marker;
  final String content;
  const FootnoteRef(this.marker, this.content);
}

/// One link found inside a cell.
class CellLink {
  final String href;
  final String title;
  const CellLink(this.href, this.title);
}

/// One content segment of a cell: either plain text, a link, or a footnote
/// marker. Links carry href/title so downstream parsers can rely on link
/// *positions* relative to surrounding text (e.g. `白露` + `型`).
class CellSegment {
  final String text;
  final String? href;
  final String? title;
  final bool isLink;
  final bool isFootnote;
  const CellSegment.text(this.text)
      : href = null,
        title = null,
        isLink = false,
        isFootnote = false;
  const CellSegment.link(this.text, this.href, this.title)
      : isLink = true,
        isFootnote = false;
  const CellSegment.footnote(this.text)
      : href = null,
        title = null,
        isLink = false,
        isFootnote = true;
}

/// A cell after expansion. [text] is the visible text with link/footnote
/// markup removed and whitespace normalized; newlines inside the original
/// cell (from `<br>` or block elements) are preserved as `\n`.
class ExpandedCell {
  final int row;
  final int col;
  final List<CellSegment> segments;
  final String rawHtml;
  final bool isHeader;

  const ExpandedCell({
    required this.row,
    required this.col,
    required this.segments,
    required this.rawHtml,
    required this.isHeader,
  });

  /// Visible text (segments concatenated, footnotes excluded).
  String get text {
    final buf = StringBuffer();
    for (final s in segments) {
      if (!s.isFootnote) buf.write(s.text);
    }
    return buf.toString();
  }

  /// All links in order.
  List<CellLink> get links => segments
      .where((s) => s.isLink && s.href != null)
      .map((s) => CellLink(s.href!, s.title ?? ''))
      .toList();

  /// Footnote refs in order (marker + tooltip content).
  List<FootnoteRef> get footnotes => segments
      .where((s) => s.isFootnote)
      .map((s) => FootnoteRef('', s.text))
      .toList();

  /// First link, or null when the cell has no link.
  CellLink? get firstLink => links.isEmpty ? null : links.first;

  bool get isEmpty => text.trim().isEmpty && links.isEmpty;
}

class TableExpansionException extends FormatException {
  @override
  final String message;
  final int row;
  final int col;
  TableExpansionException(this.message, {this.row = -1, this.col = -1})
      : super(message);
  @override
  String toString() =>
      'TableExpansionException(row=$row, col=$col): $message';
}

/// Expands [table] into a matrix without rowspan/colspan merges.
///
/// Throws [TableExpansionException] when a span overflows the table or when
/// rows end up with inconsistent widths (malformed table).
List<List<ExpandedCell?>> expandTable(Element table) {
  final rows = table.querySelectorAll('tr');
  final matrix = <List<ExpandedCell?>>[];
  final openSpans = <_OpenSpan>[];

  for (var r = 0; r < rows.length; r++) {
    final tr = rows[r];
    final row = <ExpandedCell?>[];
    var col = 0;

    for (final span in List.of(openSpans)) {
      if (span.startCol > col) break;
      if (span.remaining <= 0) {
        openSpans.remove(span);
        continue;
      }
      for (var i = 0; i < span.width; i++) {
        while (row.length < span.startCol + i) {
          row.add(null);
        }
        if (row.length == span.startCol + i) {
          row.add(span.cell);
        }
      }
      span.remaining--;
      col = span.startCol + span.width;
    }

    final rawCells = tr.children
        .where((c) => c.localName == 'td' || c.localName == 'th')
        .toList();
    for (final raw in rawCells) {
      while (row.length < col) {
        row.add(null);
      }
      final rs = _span(raw, 'rowspan', 1);
      final cs = _span(raw, 'colspan', 1);
      if (cs < 1 || rs < 1) {
        throw TableExpansionException('invalid span values', row: r, col: col);
      }
      final cell = _buildCell(raw, r, col);
      for (var i = 0; i < cs; i++) {
        row.add(cell);
      }
      if (rs > 1) {
        openSpans.add(_OpenSpan(rs - 1, col, cs, cell));
      }
      col += cs;
    }

    matrix.add(row);
  }

  for (final span in openSpans) {
    if (span.remaining > 0) {
      throw TableExpansionException(
          'rowspan overflows table (${span.remaining} rows left)',
          row: rows.length - 1,
          col: span.startCol);
    }
  }

  final widths = matrix.map((row) => row.length).toSet();
  if (widths.length > 1) {
    final w = widths.join('/');
    throw TableExpansionException(
        'inconsistent row widths after expansion ($w columns across rows)');
  }
  return matrix;
}

class _OpenSpan {
  int remaining;
  final int startCol;
  final int width;
  final ExpandedCell cell;
  _OpenSpan(this.remaining, this.startCol, this.width, this.cell);
}

int _span(Element e, String attr, int fallback) {
  final v = e.attributes[attr];
  if (v == null || v.isEmpty) return fallback;
  final n = int.tryParse(v);
  return n == null || n <= 0 ? fallback : n;
}

String _normalizeText(String raw) {
  var s = raw.replaceAll('\u00a0', ' ');
  s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
  s = s.replaceAll(RegExp(r' *\n *'), '\n');
  final lines = s.split('\n');
  final trimmed = lines.map((l) => l.trim()).toList();
  while (trimmed.isNotEmpty && trimmed.last.isEmpty) {
    trimmed.removeLast();
  }
  while (trimmed.isNotEmpty && trimmed.first.isEmpty) {
    trimmed.removeAt(0);
  }
  return trimmed.join('\n');
}

ExpandedCell _buildCell(Element raw, int row, int col) {
  final segments = <CellSegment>[];

  void walk(Element node) {
    for (final child in node.nodes) {
      if (child is Element) {
        if (child.localName == 'a') {
          final href = child.attributes['href'] ?? '';
          final title = child.attributes['title'] ?? '';
          final cls = child.className;
          if (cls.contains('note_super') && href.isEmpty) {
            // Footnote marker: keep the tooltip content as a footnote segment.
            final content = child.attributes['data-tooltip-content'] ?? '';
            segments.add(CellSegment.footnote(_decodeTooltip(content)));
          } else if (cls.contains('anchor_super')) {
            // Pure anchor: drop entirely.
          } else {
            segments.add(CellSegment.link(_normalizeText(child.text ?? ''),
                href, title.isNotEmpty ? title : child.text ?? ''));
          }
        } else if (child.localName == 'br') {
          segments.add(const CellSegment.text('\n'));
        } else if (child.localName == 'img' || child.localName == 'script' ||
            child.localName == 'style') {
          // skip
        } else {
          walk(child);
        }
      } else if (child is Text) {
        segments.add(CellSegment.text(child.text ?? ''));
      } else if (child is Comment) {
        // skip
      }
    }
  }

  walk(raw);
  // Merge adjacent text segments and normalize whitespace, preserving '\n'
  // separators that come from <br> elements.
  final merged = <CellSegment>[];
  for (final s in segments) {
    if (s.isLink || s.isFootnote) {
      merged.add(s);
      continue;
    }
    if (s.text.contains('\n')) {
      merged.add(const CellSegment.text('\n'));
      continue;
    }
    final t = _normalizeText(s.text);
    if (t.isEmpty) continue;
    final last = merged.isNotEmpty ? merged.last : null;
    if (last != null &&
        !last.isLink &&
        !last.isFootnote &&
        !last.text.contains('\n')) {
      final prev = merged.removeLast();
      merged.add(CellSegment.text(_normalizeText('${prev.text}$t')));
    } else {
      merged.add(CellSegment.text(t));
    }
  }
  final cleaned = <CellSegment>[];
  for (final s in merged) {
    if (s.isLink || s.isFootnote) {
      if (s.text.isNotEmpty) cleaned.add(s);
    } else if (s.text.contains('\n')) {
      cleaned.add(const CellSegment.text('\n'));
    } else {
      final t = _normalizeText(s.text);
      if (t.isNotEmpty) cleaned.add(CellSegment.text(t));
    }
  }
  return ExpandedCell(
    row: row,
    col: col,
    segments: cleaned,
    rawHtml: raw.outerHtml,
    isHeader: raw.localName == 'th',
  );
}

String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '').trim();

String _decodeTooltip(String content) {
  // The DOM parser already decodes character references in attribute values,
  // so content arrives as e.g. `<p>索敵+5以上の電探</p>`.
  final m = RegExp(r'<p>(.*?)</p>', dotAll: true).firstMatch(content);
  final body = m != null ? m.group(1)! : content;
  return _normalizeText(_stripTags(body));
}

/// Deterministic sha256 hash of one expanded row's raw HTML.
String rowHtmlHash(List<ExpandedCell?> row, int rowIndex) {
  final raw = row.map((c) => c?.rawHtml ?? '').join();
  final digest = sha256.convert(utf8.encode('row:$rowIndex|$raw'));
  return 'sha256:$digest';
}
