// Lightweight CSV utilities — avoids adding a new dependency.
//
// Supports double-quote escaping per RFC 4180:
//   - Fields can be wrapped in double quotes.
//   - Inside a quoted field, a literal double quote is written as "".
//   - Commas, newlines and quotes inside a quoted field are preserved.
//
// Not a full CSV implementation — no streaming, no custom delimiters — but
// sufficient for member import/export.

class CsvUtils {
  /// Parse [input] CSV text into a list of rows. Each row is a list of
  /// string cells. Empty trailing rows are dropped.
  static List<List<String>> parse(String input) {
    final rows = <List<String>>[];
    final cells = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;

    void endCell() {
      cells.add(buf.toString());
      buf.clear();
    }

    void endRow() {
      endCell();
      // Drop fully-empty trailing rows.
      if (cells.length == 1 && cells.first.isEmpty) {
        cells.clear();
        return;
      }
      rows.add(List<String>.from(cells));
      cells.clear();
    }

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];

      if (inQuotes) {
        if (ch == '"') {
          // Doubled quote inside a quoted field → literal quote.
          if (i + 1 < input.length && input[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buf.write(ch);
        }
        continue;
      }

      switch (ch) {
        case '"':
          inQuotes = true;
          break;
        case ',':
          endCell();
          break;
        case '\r':
          // Treat CR as part of CRLF; ignore — the LF will close the row.
          break;
        case '\n':
          endRow();
          break;
        default:
          buf.write(ch);
      }
    }

    // Final row (no trailing newline).
    if (buf.isNotEmpty || cells.isNotEmpty) {
      endRow();
    }

    return rows;
  }

  /// Encode [rows] as CSV text. Cells containing `,`, `"` or `\n` are quoted.
  static String encode(List<List<String>> rows) {
    final sb = StringBuffer();
    for (final row in rows) {
      for (var i = 0; i < row.length; i++) {
        if (i > 0) sb.write(',');
        sb.write(_escapeCell(row[i]));
      }
      sb.write('\n');
    }
    return sb.toString();
  }

  static String _escapeCell(String value) {
    final needsQuote = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuote) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
