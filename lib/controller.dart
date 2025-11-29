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
        text: text,         selection: newSelection,
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
    for (final delta in textEditingDeltas) {
      if (delta is TextEditingDeltaInsertion) {
        final insertOffset = delta.insertionOffset;
        final insertedText = delta.textInserted;
        
                _rope.insert(insertOffset, insertedText);
        _currentVersion++;
        _selection = delta.selection;
        
        final lineStart = _rope.findLineStart(insertOffset);
        final lineEnd = _rope.findLineEnd(insertOffset + insertedText.length);
        dirtyRegion = TextRange(start: lineStart, end: lineEnd);
        
      } else if (delta is TextEditingDeltaDeletion) {
        final deleteRange = delta.deletedRange;
        
                _rope.delete(deleteRange.start, deleteRange.end);
        _currentVersion++;
        _selection = delta.selection;
        
        final lineStart = _rope.findLineStart(deleteRange.start);
        final lineEnd = _rope.findLineEnd(deleteRange.start);
        dirtyRegion = TextRange(start: lineStart, end: lineEnd);
        
      } else if (delta is TextEditingDeltaReplacement) {
        final replaceRange = delta.replacedRange;
        final replacementText = delta.replacementText;
        
        _rope.delete(replaceRange.start, replaceRange.end);
        _rope.insert(replaceRange.start, replacementText);
        _currentVersion++;
        _selection = delta.selection;
        
        final lineStart = _rope.findLineStart(replaceRange.start);
        final lineEnd = _rope.findLineEnd(replaceRange.start + replacementText.length);
        dirtyRegion = TextRange(start: lineStart, end: lineEnd);
      }
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
