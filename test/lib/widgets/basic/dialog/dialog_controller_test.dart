/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('escapeDialogMarkdown', () {
    test('escapes markdown punctuation', () {
      expect(
        escapeDialogMarkdown(r'Path: C:\tmp\[demo](x).vst3'),
        r'Path: C:\\tmp\\\[demo\]\(x\)\.vst3',
      );
    });

    test('does not escape leading spaces', () {
      expect(escapeDialogMarkdown('  indented'), '  indented');
    });
  });

  group('escapeDialogMarkdownPreformattedText', () {
    test('escapes markdown punctuation', () {
      expect(
        escapeDialogMarkdownPreformattedText(r'Path: C:\tmp\[demo](x).vst3'),
        r'Path: C:\\tmp\\\[demo\]\(x\)\.vst3',
      );
    });

    test('escapes leading spaces after line breaks', () {
      expect(
        escapeDialogMarkdownPreformattedText('First\n    indented'),
        'First\n&nbsp;&nbsp;&nbsp;&nbsp;indented',
      );
    });

    test('escapes leading spaces at the start of input', () {
      expect(
        escapeDialogMarkdownPreformattedText('  indented'),
        '&nbsp;&nbsp;indented',
      );
    });

    test('preserves whitespace-only lines', () {
      expect(
        escapeDialogMarkdownPreformattedText('First\n    \nSecond'),
        'First\n    \nSecond',
      );
    });
  });
}
