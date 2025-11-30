import 'dart:math';

import 'package:flutter/services.dart';
import 'rope.dart';

class CodeForgeController implements DeltaTextInputClient {
  Rope _rope = Rope('');
  TextSelection _selection = const TextSelection.collapsed(offset: 0);
  TextInputConnection? connection;

  final List<VoidCallback> _listeners = [];
  TextRange? dirtyRegion;
  bool selectionOnly = false;
  String? _cachedText;
  int _cachedTextVersion = -1;
  int _currentVersion = 0;

  String get text {
    if (_cachedText == null || _cachedTextVersion != _currentVersion) {
      _cachedText = _rope.getText();
      _cachedTextVersion = _currentVersion;
    }
    return _cachedText!;
  }

  int get length => _rope.length;
  TextSelection get selection => _selection;
  List<String> get lines => _rope.cachedLines;
  int get lineCount => _rope.lineCount;
  String getLineText(int lineIndex) => _rope.getLineText(lineIndex);
  int getLineAtOffset(int charOffset) => _rope.getLineAtOffset(charOffset);
  int getLineStartOffset(int lineIndex) => _rope.getLineStartOffset(lineIndex);
  int findLineStart(int offset) => _rope.findLineStart(offset);
  int findLineEnd(int offset) => _rope.findLineEnd(offset);

  set text(String newText) {
    _rope = Rope(newText);
    _currentVersion++;
    _selection = TextSelection.collapsed(offset: newText.length);
    dirtyRegion = TextRange(start: 0, end: newText.length);
    notifyListeners();
  }

  set selection(TextSelection newSelection) {
    if (_selection == newSelection) return;

    _selection = newSelection;
    selectionOnly = true;

    if (connection != null && connection!.attached) {
      connection!.setEditingState(TextEditingValue(
        text: text,
        selection: newSelection,
      ));
    }

    notifyListeners();
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    int? dirtyStart;
    int? dirtyEnd;
    for (final delta in textEditingDeltas) {
      if (delta is TextEditingDeltaInsertion) {
        final insertOffset = delta.insertionOffset;
        final insertedText = delta.textInserted;

        _rope.insert(insertOffset, insertedText);
        _currentVersion++;
        _selection = delta.selection;

        dirtyStart = dirtyStart == null ? insertOffset : min(dirtyStart, insertOffset);
        dirtyEnd = dirtyEnd == null ? insertOffset + insertedText.length : max(dirtyEnd, insertOffset + insertedText.length);
      } else if (delta is TextEditingDeltaDeletion) {
        final deleteRange = delta.deletedRange;

        _rope.delete(deleteRange.start, deleteRange.end);
        _currentVersion++;
        _selection = delta.selection;

        dirtyStart = dirtyStart == null ? deleteRange.start : min(dirtyStart, deleteRange.start);
        dirtyEnd = dirtyEnd == null ? deleteRange.start : max(dirtyEnd, deleteRange.start);
      } else if (delta is TextEditingDeltaReplacement) {
        final replaceRange = delta.replacedRange;
        final replacementText = delta.replacementText;

        _rope.delete(replaceRange.start, replaceRange.end);
        _rope.insert(replaceRange.start, replacementText);
        _currentVersion++;
        _selection = delta.selection;

        dirtyStart = dirtyStart == null ? replaceRange.start : min(dirtyStart, replaceRange.start);
        dirtyEnd = dirtyEnd == null ? (replaceRange.start + replacementText.length) : max(dirtyEnd, replaceRange.start + replacementText.length);
      }
    }

    if (dirtyStart != null && dirtyEnd != null) {
      // Expand dirty region to whole lines to make cache invalidation simpler
      final startLine = _rope.getLineAtOffset(dirtyStart);
      final endLine = _rope.getLineAtOffset(max(0, dirtyEnd - 1));
      final startOffset = _rope.getLineStartOffset(startLine);
      final endOffset = _rope.findLineEnd(_rope.getLineStartOffset(endLine));
      dirtyRegion = TextRange(start: startOffset, end: endOffset);
    }

    notifyListeners();
  }

  void clearDirtyRegion() {
    dirtyRegion = null;
  }

  @override
  void connectionClosed() {
    connection = null;
  }

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  TextEditingValue? get currentTextEditingValue => TextEditingValue(
        text: text,
        selection: _selection,
      );

  @override
  void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {}
  @override
  void insertContent(KeyboardInsertedContent content) {}
  @override
  void insertTextPlaceholder(Size size) {}
  @override
  void performAction(TextInputAction action) {}
  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}
  @override
  void performSelector(String selectorName) {}
  @override
  void removeTextPlaceholder() {}
  @override
  void showAutocorrectionPromptRect(int start, int end) {}
  @override
  void showToolbar() {}
  @override
  void updateEditingValue(TextEditingValue value) {}
  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  void dispose() {
    _listeners.clear();
    connection?.close();
  }
}
