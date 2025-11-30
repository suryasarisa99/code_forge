import 'dart:ui' as ui;

import 'controller.dart';
import 'scroll.dart';
import 'styling.dart';

//TODO: Don't blink on typing

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class CodeForge extends StatefulWidget {
  final CodeForgeController? controller;
  final EdgeInsets? innerPadding;
  final ScrollController? verticalScrollController;
  final ScrollController? horizontalScrollController;
  final FocusNode? focusNode;
  final bool readOnly;
  final TextStyle? textStyle;
  final bool enableFolding;
  final bool enableGuideLines;
  final bool enableGutter;
  final GutterStyle? gutterStyle;
  final CodeSelectionStyle? selectionStyle;
  final Color? backgroundColor;

  const CodeForge({
    super.key,
    this.controller,
    this.innerPadding,
    this.verticalScrollController,
    this.horizontalScrollController,
    this.focusNode,
    this.readOnly = false,
    this.textStyle,
    this.enableFolding = true,
    this.enableGuideLines = true,
    this.enableGutter = true,
    this.gutterStyle,
    this.selectionStyle,
    this.backgroundColor,
  });

  @override
  State<CodeForge> createState() => _CodeForgeState();
}

class _CodeForgeState extends State<CodeForge> with SingleTickerProviderStateMixin {
  late final ScrollController _hscrollController, _vscrollController;
  late final CodeForgeController _controller;
  TextInputConnection? _connection;
  late final FocusNode _focusNode;
  late final AnimationController _caretBlinkController;

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? CodeForgeController();
    _focusNode = widget.focusNode ?? FocusNode();
    _hscrollController = widget.horizontalScrollController ?? ScrollController();
    _vscrollController = widget.verticalScrollController ?? ScrollController();

    _caretBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !widget.readOnly) {
        if (_connection == null || !_connection!.attached) {
          _connection = TextInput.attach(
            _controller,
            const TextInputConfiguration(
              readOnly: false,
              enableDeltaModel: true,
              inputType: TextInputType.multiline,
              inputAction: TextInputAction.newline,
              autocorrect: false,
            ),
          );

          _controller.connection = _connection;
          _connection!.show();
          _connection!.setEditingState(TextEditingValue(
            text: _controller.text,
            selection: _controller.selection,
          ));
        }
      }
    });
  }

  @override
  void dispose() {
    _connection?.close();
    _caretBlinkController.dispose();
    super.dispose();
  }
  
  void _handleArrowLeft(bool withShift) {
    final sel = _controller.selection;
    
    int newOffset;
    if (!withShift && sel.start != sel.end) {
      newOffset = sel.start;
    } else if (sel.extentOffset > 0) {
      newOffset = sel.extentOffset - 1;
    } else {
      newOffset = 0;
    }
    
    if (withShift) {
      _controller.setSelectionSilently(TextSelection(
        baseOffset: sel.baseOffset,
        extentOffset: newOffset,
      ));
    } else {
      _controller.setSelectionSilently(TextSelection.collapsed(offset: newOffset));
    }
  }
  
  void _handleArrowRight(bool withShift) {
    final sel = _controller.selection;
    final textLength = _controller.length;
    
    int newOffset;
    if (!withShift && sel.start != sel.end) {
      newOffset = sel.end;
    } else if (sel.extentOffset < textLength) {
      newOffset = sel.extentOffset + 1;
    } else {
      newOffset = textLength;
    }
    
    if (withShift) {
      _controller.setSelectionSilently(TextSelection(
        baseOffset: sel.baseOffset,
        extentOffset: newOffset,
      ));
    } else {
      _controller.setSelectionSilently(TextSelection.collapsed(offset: newOffset));
    }
  }
  
  void _handleArrowUp(bool withShift) {
    final sel = _controller.selection;
    final currentLine = _controller.getLineAtOffset(sel.extentOffset);
    
    if (currentLine <= 0) {
      if (withShift) {
        _controller.setSelectionSilently(TextSelection(
          baseOffset: sel.baseOffset,
          extentOffset: 0,
        ));
      } else {
        _controller.setSelectionSilently(const TextSelection.collapsed(offset: 0));
      }
      return;
    }
    
    final lineStart = _controller.getLineStartOffset(currentLine);
    final column = sel.extentOffset - lineStart;
    final prevLineStart = _controller.getLineStartOffset(currentLine - 1);
    final prevLineText = _controller.getLineText(currentLine - 1);
    final prevLineLength = prevLineText.length;
    final newColumn = column.clamp(0, prevLineLength);
    final newOffset = prevLineStart + newColumn;
    
    if (withShift) {
      _controller.setSelectionSilently(TextSelection(
        baseOffset: sel.baseOffset,
        extentOffset: newOffset,
      ));
    } else {
      _controller.setSelectionSilently(TextSelection.collapsed(offset: newOffset));
    }
  }
  
  void _handleArrowDown(bool withShift) {
    final sel = _controller.selection;
    final currentLine = _controller.getLineAtOffset(sel.extentOffset);
    final lineCount = _controller.lineCount;
    
    if (currentLine >= lineCount - 1) {
      final endOffset = _controller.length;
      if (withShift) {
        _controller.setSelectionSilently(TextSelection(
          baseOffset: sel.baseOffset,
          extentOffset: endOffset,
        ));
      } else {
        _controller.setSelectionSilently(TextSelection.collapsed(offset: endOffset));
      }
      return;
    }
    
    final lineStart = _controller.getLineStartOffset(currentLine);
    final column = sel.extentOffset - lineStart;
    final nextLineStart = _controller.getLineStartOffset(currentLine + 1);
    final nextLineText = _controller.getLineText(currentLine + 1);
    final nextLineLength = nextLineText.length;
    final newColumn = column.clamp(0, nextLineLength);
    final newOffset = nextLineStart + newColumn;
    
    if (withShift) {
      _controller.setSelectionSilently(TextSelection(
        baseOffset: sel.baseOffset,
        extentOffset: newOffset,
      ));
    } else {
      _controller.setSelectionSilently(TextSelection.collapsed(offset: newOffset));
    }
  }
  
  void _handleHome(bool withShift) {
    final sel = _controller.selection;
    final currentLine = _controller.getLineAtOffset(sel.extentOffset);
    final lineStart = _controller.getLineStartOffset(currentLine);
    
    if (withShift) {
      _controller.setSelectionSilently(TextSelection(
        baseOffset: sel.baseOffset,
        extentOffset: lineStart,
      ));
    } else {
      _controller.setSelectionSilently(TextSelection.collapsed(offset: lineStart));
    }
  }
  
  void _handleEnd(bool withShift) {
    final sel = _controller.selection;
    final currentLine = _controller.getLineAtOffset(sel.extentOffset);
    final lineText = _controller.getLineText(currentLine);
    final lineStart = _controller.getLineStartOffset(currentLine);
    final lineEnd = lineStart + lineText.length;
    
    if (withShift) {
      _controller.setSelectionSilently(TextSelection(
        baseOffset: sel.baseOffset,
        extentOffset: lineEnd,
      ));
    } else {
      _controller.setSelectionSilently(TextSelection.collapsed(offset: lineEnd));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        return GestureDetector(
          onTap: _focusNode.requestFocus,
          child: RawScrollbar(
            controller: _vscrollController,
            thumbVisibility: true,
            child: RawScrollbar(
              thumbVisibility: true,
              controller: _hscrollController,
              child: TwoDimensionalScrollable(
                horizontalDetails: ScrollableDetails.horizontal(
                  controller: _hscrollController,
                  physics: const ClampingScrollPhysics()
                ),
                verticalDetails: ScrollableDetails.vertical(
                  controller: _vscrollController,
                  physics: const ClampingScrollPhysics()
                ),
                viewportBuilder: (_, voffset, hoffset) => CustomViewport(
                  verticalOffset: voffset,
                  verticalAxisDirection: AxisDirection.down,
                  horizontalOffset: hoffset,
                  horizontalAxisDirection: AxisDirection.right,
                  mainAxis: Axis.vertical,
                  delegate: TwoDimensionalChildBuilderDelegate(
                    maxXIndex: 0,
                    maxYIndex: 0,
                    builder: (_, vic){
                      return Focus(
                        focusNode: _focusNode,
                        onKeyEvent: (node, event) {
                          if(event is KeyDownEvent || event is KeyRepeatEvent){
                            final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
                            switch (event.logicalKey) {
                              case LogicalKeyboardKey.backspace:
                                _controller.backspace();
                                return KeyEventResult.handled;
                              case LogicalKeyboardKey.delete:
                                _controller.delete();
                                return KeyEventResult.handled;
                              case LogicalKeyboardKey.arrowDown:
                                _handleArrowDown(isShiftPressed);
                                return KeyEventResult.handled;
                              case LogicalKeyboardKey.arrowUp:
                                _handleArrowUp(isShiftPressed);
                                return KeyEventResult.handled;
                              case LogicalKeyboardKey.arrowRight:
                                _handleArrowRight(isShiftPressed);
                                return KeyEventResult.handled;
                              case LogicalKeyboardKey.arrowLeft:
                                _handleArrowLeft(isShiftPressed);
                                return KeyEventResult.handled;
                              case LogicalKeyboardKey.home:
                                _handleHome(isShiftPressed);
                                return KeyEventResult.handled;
                              case LogicalKeyboardKey.end:
                                _handleEnd(isShiftPressed);
                                return KeyEventResult.handled;
                              default:
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: _CodeField(
                          _controller,
                          widget.innerPadding,
                          _vscrollController,
                          _hscrollController,
                          _focusNode,
                          widget.readOnly,
                          _caretBlinkController,
                          widget.textStyle,
                          widget.enableFolding,
                          widget.enableGuideLines,
                          widget.enableGutter,
                          widget.gutterStyle ?? const GutterStyle(),
                          widget.selectionStyle ?? const CodeSelectionStyle(),
                          widget.backgroundColor,
                        ),
                      );
                    }
                  )
                )
              ),
            ),
          ),
        );
      }
    );
  }
}

class _CodeField extends LeafRenderObjectWidget{
  final CodeForgeController controller;
  final EdgeInsets? innerPadding;
  final ScrollController vscrollController, hscrollController;
  final FocusNode focusNode;
  final bool readOnly;
  final AnimationController caretBlinkController;
  final TextStyle? textStyle;
  final bool enableFolding;
  final bool enableGuideLines;
  final bool enableGutter;
  final GutterStyle gutterStyle;
  final CodeSelectionStyle selectionStyle;
  final Color? backgroundColor;

  const _CodeField(
    this.controller,
    this.innerPadding,
    this.vscrollController,
    this.hscrollController,
    this.focusNode,
    this.readOnly,
    this.caretBlinkController,
    this.textStyle,
    this.enableFolding,
    this.enableGuideLines,
    this.enableGutter,
    this.gutterStyle,
    this.selectionStyle,
    this.backgroundColor,
  );

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _CodeFieldRenderer(
      controller,
      innerPadding,
      vscrollController,
      hscrollController,
      focusNode,
      readOnly,
      caretBlinkController,
      textStyle,
      enableFolding,
      enableGuideLines,
      enableGutter,
      gutterStyle,
      selectionStyle,
      backgroundColor,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {

  }

}

class _CodeFieldRenderer extends RenderBox {
  final CodeForgeController controller;
  final EdgeInsets? innerPadding;
  final ScrollController vscrollController, hscrollController;
  final FocusNode focusNode;
  final bool readOnly;
  final AnimationController caretBlinkController;
  final TextStyle? textStyle;
  final bool enableFolding;
  final bool enableGuideLines;
  final bool enableGutter;
  final GutterStyle gutterStyle;
  final CodeSelectionStyle selectionStyle;
  final Color? backgroundColor;
  final Map<int, double> _lineWidthCache = {};
  final Map<int, String> _lineTextCache = {};
  final Map<int, ui.Paragraph> _paragraphCache = {};
  final List<FoldRange> _foldRanges = [];
  late final double _lineHeight;
  late final double _gutterPadding;
  late final Paint _caretPainter;
  late final Paint _bracketHighlightPainter;
  late final ui.ParagraphStyle _paragraphStyle;
  late final ui.TextStyle _uiTextStyle;
  late double _gutterWidth;
  int _cachedLineCount = 0;
  bool _foldRangesNeedsClear = false;
  int _cachedCaretOffset = -1;
  int _cachedCaretLine = 0;
  int _cachedCaretLineStart = 0;
  
  ui.Paragraph _buildParagraph(String text) {
    final builder = ui.ParagraphBuilder(_paragraphStyle)
      ..pushStyle(_uiTextStyle)
      ..addText(text.isEmpty ? ' ' : text);
    final p = builder.build();
    p.layout(const ui.ParagraphConstraints(width: double.infinity));
    return p;
  }

  _CodeFieldRenderer(
    this.controller,
    this.innerPadding,
    this.vscrollController,
    this.hscrollController,
    this.focusNode,
    this.readOnly,
    this.caretBlinkController,
    this.textStyle,
    this.enableFolding,
    this.enableGuideLines,
    this.enableGutter,
    this.gutterStyle,
    this.selectionStyle,
    this.backgroundColor,
  ) {
    final fontSize = textStyle?.fontSize ?? 14.0;
    final fontFamily = textStyle?.fontFamily;
    final color = textStyle?.color ?? Colors.black;
    final lineHeightMultiplier = textStyle?.height ?? 1.2;
    
    _lineHeight = fontSize * lineHeightMultiplier;
    
    _gutterPadding = fontSize;
    if (enableGutter) {
      if (gutterStyle.gutterWidth != null) {
        _gutterWidth = gutterStyle.gutterWidth!;
      } else {
        final digits = controller.lineCount.toString().length;
        final digitWidth = digits * _gutterPadding * 0.6;
        final foldIconSpace = enableFolding ? fontSize + 4 : 0;
        _gutterWidth = digitWidth + foldIconSpace + _gutterPadding;
      }
    } else {
      _gutterWidth = 0;
    }
    _cachedLineCount = controller.lineCount;
    
    _caretPainter = Paint()
      ..color = selectionStyle.cursorColor ?? color
      ..style = PaintingStyle.fill;
    
    _bracketHighlightPainter = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    
    _paragraphStyle = ui.ParagraphStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: lineHeightMultiplier,
    );
    _uiTextStyle = ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );
    
    vscrollController.addListener(markNeedsPaint);
    hscrollController.addListener(markNeedsPaint);
    caretBlinkController.addListener(markNeedsPaint);
    controller.addListener(_onControllerChange);
  }

  void _ensureCaretVisible() {
    if (!vscrollController.hasClients || !hscrollController.hasClients) return;
    
    final caretInfo = _getCaretInfo();
    final caretX = caretInfo.offset.dx + _gutterWidth + (innerPadding?.left ?? 0);
    final caretY = caretInfo.offset.dy + (innerPadding?.top ?? 0);
    final caretHeight = caretInfo.height;
    final vScrollOffset = vscrollController.offset;
    final hScrollOffset = hscrollController.offset;
    final viewportHeight = vscrollController.position.viewportDimension;
    final viewportWidth = hscrollController.position.viewportDimension;

    if (caretY > 0 && caretY <= vScrollOffset + (innerPadding?.top ?? 0)) {
      vscrollController.animateTo(
        caretY - (innerPadding?.top ?? 0),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (caretY + caretHeight >= vScrollOffset + viewportHeight) {
      vscrollController.animateTo(
        caretY + caretHeight - viewportHeight + (innerPadding?.bottom ?? 0),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }

    if (caretX < hScrollOffset + (innerPadding?.left ?? 0) + _gutterWidth) {
      hscrollController.animateTo(
        caretX - (innerPadding?.left ?? 0) - _gutterWidth,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (caretX + 1.5 > hScrollOffset + viewportWidth) {
      hscrollController.animateTo(
        caretX + 1.5 - viewportWidth + (innerPadding?.right ?? 0) + _gutterWidth,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void _onControllerChange() {
    if (controller.selectionOnly) {
      controller.selectionOnly = false;
      markNeedsPaint();
      return;
    }
    
    if (controller.bufferNeedsRepaint) {
      controller.bufferNeedsRepaint = false;
      _ensureCaretVisible();
      markNeedsPaint();
      return;
    }

    final newLineCount = controller.lineCount;
    final lineCountChanged = newLineCount != _cachedLineCount;

    final affectedLine = controller.dirtyLine;
    if (affectedLine != null) {
      _lineWidthCache.remove(affectedLine);
      _lineTextCache.remove(affectedLine);
      _paragraphCache.remove(affectedLine);
    }
    controller.clearDirtyRegion();

    if (lineCountChanged) {
      _cachedLineCount = newLineCount;
      _lineTextCache.clear();
      _paragraphCache.clear();
      
      if (enableGutter && gutterStyle.gutterWidth == null) {
        final fontSize = textStyle?.fontSize ?? 14.0;
        final digits = newLineCount.toString().length;
        final digitWidth = digits * _gutterPadding * 0.6;
        final foldIconSpace = enableFolding ? fontSize + 4 : 0;
        _gutterWidth = digitWidth + foldIconSpace + _gutterPadding;
      }
      
      if (enableFolding) {
        _foldRangesNeedsClear = true;
      }
      
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
    
    _ensureCaretVisible();
  }
  
  FoldRange? _computeFoldRangeForLine(int lineIndex) {
    if (!enableFolding) return null;
    
    final line = controller.getLineText(lineIndex);
    
    if (line.contains('{')) {
      int braceCount = 0;
      bool foundOpen = false;
      
      for (int i = lineIndex; i < controller.lineCount; i++) {
        final checkLine = controller.getLineText(i);
        for (int c = 0; c < checkLine.length; c++) {
          if (checkLine[c] == '{') {
            if (!foundOpen && i == lineIndex) foundOpen = true;
            braceCount++;
          } else if (checkLine[c] == '}') {
            braceCount--;
            if (braceCount == 0 && foundOpen && i > lineIndex) {
              return FoldRange(lineIndex, i);
            }
          }
        }
      }
    }
    
    if (line.trim().endsWith(':')) {
      final startIndent = line.length - line.trimLeft().length;
      int endLine = lineIndex;
      
      for (int j = lineIndex + 1; j < controller.lineCount; j++) {
        final next = controller.getLineText(j);
        if (next.trim().isEmpty) continue;
        final nextIndent = next.length - next.trimLeft().length;
        if (nextIndent <= startIndent) break;
        endLine = j;
      }
      
      if (endLine > lineIndex) {
        return FoldRange(lineIndex, endLine);
      }
    }
    
    return null;
  }
  
  FoldRange? _getOrComputeFoldRange(int lineIndex) {
    if (_foldRangesNeedsClear) {
      _foldRanges.removeWhere((f) => !f.isFolded);
      _foldRangesNeedsClear = false;
    }
    
    try {
      return _foldRanges.firstWhere((f) => f.startIndex == lineIndex);
    } catch (_) {
      final fold = _computeFoldRangeForLine(lineIndex);
      if (fold != null) {
        _foldRanges.add(fold);
        _foldRanges.sort((a, b) => a.startIndex.compareTo(b.startIndex));
      }
      return fold;
    }
  }
  
  void _toggleFold(FoldRange fold) {
    if (fold.isFolded) {
      _unfoldWithChildren(fold);
    } else {
      _foldWithChildren(fold);
    }
    markNeedsLayout();
    markNeedsPaint();
  }
  
  void _foldWithChildren(FoldRange parentFold) {
    parentFold.clearOriginallyFoldedChildren();
    
    for (final childFold in _foldRanges) {
      if (childFold.isFolded && 
          childFold != parentFold &&
          childFold.startIndex > parentFold.startIndex && 
          childFold.endIndex <= parentFold.endIndex) {
        parentFold.addOriginallyFoldedChild(childFold);
        childFold.isFolded = false;
      }
    }
    
    parentFold.isFolded = true;
  }
  
  void _unfoldWithChildren(FoldRange parentFold) {
    parentFold.isFolded = false;
    for (final childFold in parentFold.originallyFoldedChildren) {
      if (childFold.startIndex > parentFold.startIndex && 
          childFold.endIndex <= parentFold.endIndex) {
        childFold.isFolded = true;
      }
    }
    parentFold.clearOriginallyFoldedChildren();
  }
  
  bool _isLineFolded(int lineIndex) {
    return _foldRanges.any((fold) => 
      fold.isFolded && lineIndex > fold.startIndex && lineIndex <= fold.endIndex
    );
  }
  
  /// Finds the matching bracket for the bracket at [pos] in [text].
  /// Returns the index of the matching bracket, or null if not found.
  int? _findMatchingBracket(String text, int pos) {
    const Map<String, String> pairs = {
      '(': ')', '{': '}', '[': ']',
      ')': '(', '}': '{', ']': '[',
    };
    const String openers = '({[';

    if (pos < 0 || pos >= text.length) return null;

    final char = text[pos];
    if (!pairs.containsKey(char)) return null;

    final match = pairs[char]!;
    final isForward = openers.contains(char);

    int depth = 0;
    if (isForward) {
      for (int i = pos + 1; i < text.length; i++) {
        if (text[i] == char) depth++;
        if (text[i] == match) {
          if (depth == 0) return i;
          depth--;
        }
      }
    } else {
      for (int i = pos - 1; i >= 0; i--) {
        if (text[i] == char) depth++;
        if (text[i] == match) {
          if (depth == 0) return i;
          depth--;
        }
      }
    }
    return null;
  }
  
  /// Finds matching bracket pair at cursor position.
  /// Returns (bracket1, bracket2) as global text offsets, or (null, null) if none.
  (int?, int?) _getBracketPairAtCursor() {
    final cursorOffset = controller.selection.extentOffset;
    final text = controller.text;
    
    if (cursorOffset < 0 || text.isEmpty) return (null, null);
    
    if (cursorOffset > 0) {
      final before = text[cursorOffset - 1];
      if ('{}[]()'.contains(before)) {
        final match = _findMatchingBracket(text, cursorOffset - 1);
        if (match != null) {
          return (cursorOffset - 1, match);
        }
      }
    }
    
    if (cursorOffset < text.length) {
      final after = text[cursorOffset];
      if ('{}[]()'.contains(after)) {
        final match = _findMatchingBracket(text, cursorOffset);
        if (match != null) {
          return (cursorOffset, match);
        }
      }
    }
    
    return (null, null);
  }
  
  FoldRange? _getFoldRangeAtLine(int lineIndex) {
    if (!enableFolding) return null;
    return _getOrComputeFoldRange(lineIndex);
  }

  int _findVisibleLineByYPosition(double y) {
    final lineCount = controller.lineCount;
    if (lineCount == 0) return 0;
    
    final hasActiveFolds = _foldRanges.any((f) => f.isFolded);
    
    if (!hasActiveFolds) {
      return (y / _lineHeight).floor().clamp(0, lineCount - 1);
    }
    
    double currentY = 0;
    for (int i = 0; i < lineCount; i++) {
      if (_isLineFolded(i)) continue;
      if (currentY + _lineHeight > y) {
        return i;
      }
      currentY += _lineHeight;
    }
    return lineCount - 1;
  }

  ({int lineIndex, int columnIndex, Offset offset, double height}) _getCaretInfo() {
    final lineCount = controller.lineCount;
    if (lineCount == 0) {
      return (lineIndex: 0, columnIndex: 0, offset: Offset.zero, height: _lineHeight);
    }
    
    if (controller.isBufferActive) {
      final lineIndex = controller.bufferLineIndex!;
      final columnIndex = controller.bufferCursorColumn;
      final lineY = lineIndex * _lineHeight;
      final lineText = controller.bufferLineText ?? '';
      
      final para = _buildParagraph(lineText);
      final clampedCol = columnIndex.clamp(0, lineText.length);
      double caretX = 0.0;
      if (clampedCol > 0) {
        final boxes = para.getBoxesForRange(0, clampedCol);
        if (boxes.isNotEmpty) {
          caretX = boxes.last.right;
        }
      }
      
      return (
        lineIndex: lineIndex,
        columnIndex: columnIndex,
        offset: Offset(caretX, lineY),
        height: _lineHeight,
      );
    }

    final cursorOffset = controller.selection.extentOffset;
    
    int lineIndex;
    int lineStartOffset;
    if (cursorOffset == _cachedCaretOffset) {
      lineIndex = _cachedCaretLine;
      lineStartOffset = _cachedCaretLineStart;
    } else {
      lineIndex = controller.getLineAtOffset(cursorOffset);
      lineStartOffset = controller.getLineStartOffset(lineIndex);
      _cachedCaretOffset = cursorOffset;
      _cachedCaretLine = lineIndex;
      _cachedCaretLineStart = lineStartOffset;
    }
    
    final columnIndex = cursorOffset - lineStartOffset;
    final lineY = lineIndex * _lineHeight;
    
    String lineText;
    if (_lineTextCache.containsKey(lineIndex)) {
      lineText = _lineTextCache[lineIndex]!;
    } else {
      lineText = controller.getLineText(lineIndex);
      _lineTextCache[lineIndex] = lineText;
      _paragraphCache.remove(lineIndex);
    }

    ui.Paragraph para;
    if (_paragraphCache.containsKey(lineIndex)) {
      para = _paragraphCache[lineIndex]!;
    } else {
      para = _buildParagraph(lineText);
      _paragraphCache[lineIndex] = para;
    }
    
    final clampedCol = columnIndex.clamp(0, lineText.length);
    double caretX = 0.0;
    if (clampedCol > 0) {
      final boxes = para.getBoxesForRange(0, clampedCol);
      if (boxes.isNotEmpty) {
        caretX = boxes.last.right;
      }
    }

    return (
      lineIndex: lineIndex,
      columnIndex: columnIndex,
      offset: Offset(caretX, lineY),
      height: _lineHeight,
    );
  }

  int _getTextOffsetFromPosition(Offset position) {
    final lineCount = controller.lineCount;
    if (lineCount == 0) return 0;

    final tappedLineIndex = _findVisibleLineByYPosition(position.dy);

    String lineText;
    if (_lineTextCache.containsKey(tappedLineIndex)) {
      lineText = _lineTextCache[tappedLineIndex]!;
    } else {
      lineText = controller.getLineText(tappedLineIndex);
      _lineTextCache[tappedLineIndex] = lineText;
      _paragraphCache.remove(tappedLineIndex);
    }

    ui.Paragraph para;
    if (_paragraphCache.containsKey(tappedLineIndex)) {
      para = _paragraphCache[tappedLineIndex]!;
    } else {
      para = _buildParagraph(lineText);
      _paragraphCache[tappedLineIndex] = para;
    }
    
    final localX = position.dx;
    final textPosition = para.getPositionForOffset(Offset(localX, _lineHeight / 2));
    final columnIndex = textPosition.offset.clamp(0, lineText.length);
    
    final lineStartOffset = controller.getLineStartOffset(tappedLineIndex);
    final absoluteOffset = lineStartOffset + columnIndex;

    return absoluteOffset.clamp(0, controller.length);
  }

  @override
  void performLayout() {
    final lineCount = controller.lineCount;
    
    final hasActiveFolds = _foldRanges.any((f) => f.isFolded);
    double visibleHeight;
    
    if (!hasActiveFolds) {
      visibleHeight = lineCount * _lineHeight;
    } else {
      visibleHeight = 0;
      for (int i = 0; i < lineCount; i++) {
        if (!_isLineFolded(i)) {
          visibleHeight += _lineHeight;
        }
      }
    }
    
    final contentHeight = visibleHeight + (innerPadding?.vertical ?? 0);

    const estimatedMaxWidth = 2000.0;
    final contentWidth = estimatedMaxWidth + (innerPadding?.horizontal ?? 0) + _gutterWidth;

    size = constraints.constrain(Size(contentWidth, contentHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final viewTop = vscrollController.offset;
    final viewBottom = viewTop + vscrollController.position.viewportDimension;
    final lineCount = controller.lineCount;
    
    final bufferActive = controller.isBufferActive;
    final bufferLineIndex = controller.bufferLineIndex;
    final bufferLineText = controller.bufferLineText;
    
    final bgColor = backgroundColor ?? Colors.white;
    final textColor = textStyle?.color ?? Colors.black;
    final fontSize = textStyle?.fontSize ?? 14.0;

    canvas.save();
    
    canvas.drawRect(offset & size, Paint()..color = bgColor);
    
    final hasActiveFolds = _foldRanges.any((f) => f.isFolded);
    
    int firstVisibleLine;
    int lastVisibleLine;
    double firstVisibleLineY;
    
    if (!hasActiveFolds) {
      firstVisibleLine = (viewTop / _lineHeight).floor().clamp(0, lineCount - 1);
      lastVisibleLine = (viewBottom / _lineHeight).ceil().clamp(0, lineCount - 1);
      firstVisibleLineY = firstVisibleLine * _lineHeight;
    } else {
      double currentY = 0;
      firstVisibleLine = 0;
      lastVisibleLine = lineCount - 1;
      firstVisibleLineY = 0;
      
      for (int i = 0; i < lineCount; i++) {
        if (_isLineFolded(i)) continue;
        if (currentY + _lineHeight > viewTop) {
          firstVisibleLine = i;
          firstVisibleLineY = currentY;
          break;
        }
        currentY += _lineHeight;
      }
      
      currentY = firstVisibleLineY;
      for (int i = firstVisibleLine; i < lineCount; i++) {
        if (_isLineFolded(i)) continue;
        currentY += _lineHeight;
        if (currentY >= viewBottom) {
          lastVisibleLine = i;
          break;
        }
      }
    }
    
    if (enableGuideLines && (lastVisibleLine - firstVisibleLine) < 200) {
      _drawIndentGuides(
        canvas,
        offset,
        firstVisibleLine,
        lastVisibleLine, 
        firstVisibleLineY,
        hasActiveFolds,
        textColor
      );
    }
    
    double currentY = firstVisibleLineY;
    for (int i = firstVisibleLine; i <= lastVisibleLine && i < lineCount; i++) {
      if (hasActiveFolds && _isLineFolded(i)) continue;
      
      final contentTop = currentY;
      
      ui.Paragraph paragraph;
      String lineText;
      
      if (bufferActive && i == bufferLineIndex && bufferLineText != null) {
        lineText = bufferLineText;
        paragraph = _buildParagraph(bufferLineText);
      } else {
        if (_lineTextCache.containsKey(i)) {
          lineText = _lineTextCache[i]!;
        } else {
          lineText = controller.getLineText(i);
          _lineTextCache[i] = lineText;
        }
        
        if (_paragraphCache.containsKey(i)) {
          paragraph = _paragraphCache[i]!;
        } else {
          paragraph = _buildParagraph(lineText);
          _paragraphCache[i] = paragraph;
        }
      }
      
      final foldRange = _getFoldRangeAtLine(i);
      final isFoldStart = foldRange != null;
      
      canvas.drawParagraph(
        paragraph,
        offset + Offset(
          _gutterWidth + (innerPadding?.left ?? 0) - hscrollController.offset,
          (innerPadding?.top ?? 0) + contentTop - vscrollController.offset
        )
      );
      
      if (isFoldStart && foldRange.isFolded) {
        final foldIndicator = _buildParagraph(' ...');
        final paraWidth = paragraph.longestLine;
        canvas.drawParagraph(
          foldIndicator,
          offset + Offset(
            _gutterWidth + (innerPadding?.left ?? 0) + paraWidth - hscrollController.offset,
            (innerPadding?.top ?? 0) + contentTop - vscrollController.offset
          )
        );
      }
      
      currentY += _lineHeight;
    }
    
    if (enableGutter) {
      _drawGutter(canvas, offset, viewTop, viewBottom, lineCount, fontSize, textColor, bgColor);
    }
    
    if (focusNode.hasFocus) {
      _drawBracketHighlight(
        canvas, offset, viewTop, viewBottom, 
        firstVisibleLine, lastVisibleLine, firstVisibleLineY, 
        hasActiveFolds, textColor
      );
    }

    if (focusNode.hasFocus && caretBlinkController.value > 0.5) {
      final caretInfo = _getCaretInfo();
      
      double caretY;
      if (!hasActiveFolds) {
        caretY = caretInfo.lineIndex * _lineHeight;
      } else {
        caretY = 0;
        for (int i = 0; i < caretInfo.lineIndex; i++) {
          if (!_isLineFolded(i)) {
            caretY += _lineHeight;
          }
        }
      }

      final caretX = _gutterWidth + (innerPadding?.left ?? 0)
        + caretInfo.offset.dx
        - hscrollController.offset;
      final caretScreenY = (innerPadding?.top ?? 0)
        + caretY
        - vscrollController.offset;

      canvas.drawRect(
        Rect.fromLTWH(
          caretX,
          caretScreenY,
          1.5,
          caretInfo.height
        ),
        _caretPainter,
      );
    }

    canvas.restore();
  }
  
  void _drawGutter(Canvas canvas, Offset offset, double viewTop, double viewBottom, 
      int lineCount, double fontSize, Color textColor, Color bgColor) {
    final viewportHeight = vscrollController.position.viewportDimension;
    
    final gutterBgColor = gutterStyle.backgroundColor ?? bgColor;
    canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy, _gutterWidth, viewportHeight),
      Paint()..color = gutterBgColor
    );
    
    final dividerPaint = Paint()
      //TODO
      ..color = textColor.withOpacity(0.2)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(offset.dx + _gutterWidth - 1, offset.dy),
      Offset(offset.dx + _gutterWidth - 1, offset.dy + viewportHeight),
      dividerPaint,
    );
    
    final lineNumberStyle = gutterStyle.lineNumberStyle ?? TextStyle(
      //TODO
      color: textColor.withOpacity(0.6),
      fontSize: fontSize,
    );
    
    final hasActiveFolds = _foldRanges.any((f) => f.isFolded);
    
    int firstVisibleLine;
    double firstVisibleLineY;
    
    if (!hasActiveFolds) {
      firstVisibleLine = (viewTop / _lineHeight).floor().clamp(0, lineCount - 1);
      firstVisibleLineY = firstVisibleLine * _lineHeight;
    } else {
      double currentY = 0;
      firstVisibleLine = 0;
      firstVisibleLineY = 0;
      
      for (int i = 0; i < lineCount; i++) {
        if (_isLineFolded(i)) continue;
        if (currentY + _lineHeight > viewTop) {
          firstVisibleLine = i;
          firstVisibleLineY = currentY;
          break;
        }
        currentY += _lineHeight;
      }
    }
    
    double currentY = firstVisibleLineY;
    for (int i = firstVisibleLine; i < lineCount; i++) {
      if (hasActiveFolds && _isLineFolded(i)) continue;
      
      final contentTop = currentY;
      
      if (contentTop > viewBottom) break;
      
      if (contentTop + _lineHeight >= viewTop) {
        final lineNumPara = _buildLineNumberParagraph((i + 1).toString(), lineNumberStyle);
        final numWidth = lineNumPara.longestLine;
        
        canvas.drawParagraph(
          lineNumPara,
          offset + Offset(
            (_gutterWidth - numWidth) / 2 - (enableFolding ? fontSize / 2 : 0),
            (innerPadding?.top ?? 0) + contentTop - vscrollController.offset
          )
        );
        
        if (enableFolding) {
          final foldRange = _getFoldRangeAtLine(i);
          if (foldRange != null) {
            final isInsideFoldedParent = _foldRanges.any(
              (parent) => parent.isFolded && parent.startIndex < i && parent.endIndex >= i
            );
            
            if (!isInsideFoldedParent) {
              final icon = foldRange.isFolded ? gutterStyle.foldedIcon : gutterStyle.unfoldedIcon;
              final iconColor = foldRange.isFolded 
                  ? (gutterStyle.foldedIconColor ?? textColor)
                  //TODO
                  : (gutterStyle.unfoldedIconColor ?? textColor.withOpacity(0.6));
              
              _drawFoldIcon(canvas, offset, icon, iconColor, fontSize, contentTop - vscrollController.offset);
            }
          }
        }
      }
      
      currentY += _lineHeight;
    }
  }
  
  ui.Paragraph _buildLineNumberParagraph(String text, TextStyle style) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: style.fontSize,
      fontFamily: style.fontFamily,
    ))
      ..pushStyle(ui.TextStyle(
        color: style.color,
        fontSize: style.fontSize,
        fontFamily: style.fontFamily,
      ))
      ..addText(text);
    final p = builder.build();
    p.layout(const ui.ParagraphConstraints(width: double.infinity));
    return p;
  }
  
  void _drawFoldIcon(Canvas canvas, Offset offset, IconData icon, Color color, double fontSize, double y) {
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      offset + Offset(
        _gutterWidth - iconPainter.width - 2,
        (innerPadding?.top ?? 0) + y + (_lineHeight - iconPainter.height) / 2
      ),
    );
  }
  
  void _drawIndentGuides(
      Canvas canvas, Offset offset, int firstVisibleLine, 
      int lastVisibleLine, double firstVisibleLineY, 
      bool hasActiveFolds, Color textColor
    ) {
    final viewTop = vscrollController.offset;
    final viewBottom = viewTop + vscrollController.position.viewportDimension;
    final tabSize = 4;
    final cursorOffset = controller.selection.extentOffset;
    final currentLine = controller.getLineAtOffset(cursorOffset);
    List<({int startLine, int endLine, int indentLevel, double guideX})> blocks = [];
    
    void processLine(int i) {
      if (hasActiveFolds && _isLineFolded(i)) return;
      
      String lineText;
      if (_lineTextCache.containsKey(i)) {
        lineText = _lineTextCache[i]!;
      } else {
        lineText = controller.getLineText(i);
        _lineTextCache[i] = lineText;
      }
      
      final trimmed = lineText.trimRight();
      if (!trimmed.endsWith('{') && !trimmed.endsWith(':')) return;
      
      final leadingSpaces = lineText.length - lineText.trimLeft().length;
      final indentLevel = leadingSpaces ~/ tabSize;
      
      int endLine = i + 1;
      while (endLine < controller.lineCount) {
        if (hasActiveFolds && _isLineFolded(endLine)) {
          endLine++;
          continue;
        }
        
        String nextLine;
        if (_lineTextCache.containsKey(endLine)) {
          nextLine = _lineTextCache[endLine]!;
        } else {
          nextLine = controller.getLineText(endLine);
          _lineTextCache[endLine] = nextLine;
        }
        
        if (nextLine.trim().isEmpty) {
          endLine++;
          continue;
        }
        
        final nextLeading = nextLine.length - nextLine.trimLeft().length;
        if (nextLeading <= leadingSpaces) break;
        endLine++;
      }
      
      if (endLine <= i + 1) return;
      
      if (endLine < firstVisibleLine) return;
      
      ui.Paragraph para;
      if (_paragraphCache.containsKey(i)) {
        para = _paragraphCache[i]!;
      } else {
        para = _buildParagraph(lineText);
        _paragraphCache[i] = para;
      }
      
      double guideX;
      if (leadingSpaces > 0) {
        final boxes = para.getBoxesForRange(0, leadingSpaces);
        guideX = boxes.isNotEmpty ? boxes.last.right : 0;
      } else {
        guideX = 0;
      }
      
      blocks.add((startLine: i, endLine: endLine, indentLevel: indentLevel, guideX: guideX));
    }
    
    final scanBackLimit = 500;
    final scanStart = (firstVisibleLine - scanBackLimit).clamp(0, firstVisibleLine);
    for (int i = scanStart; i < firstVisibleLine; i++) {
      processLine(i);
    }
    
    for (int i = firstVisibleLine; i <= lastVisibleLine && i < controller.lineCount; i++) {
      processLine(i);
    }
    
    int? selectedBlockIndex;
    int minBlockSize = 999999;
    
    for (int idx = 0; idx < blocks.length; idx++) {
      final block = blocks[idx];
      if (currentLine >= block.startLine && currentLine < block.endLine) {
        final blockSize = block.endLine - block.startLine;
        if (blockSize < minBlockSize) {
          minBlockSize = blockSize;
          selectedBlockIndex = idx;
        }
      }
    }
    
    for (int idx = 0; idx < blocks.length; idx++) {
      final block = blocks[idx];
      final isSelected = selectedBlockIndex == idx;
      
      final guidePaint = Paint()
        ..color = isSelected 
        //TODO
            ? textColor.withOpacity(0.5)
            : textColor.withOpacity(0.15)
        ..strokeWidth = isSelected ? 1.0 : 0.5
        ..style = PaintingStyle.stroke;
      
      double yTop;
      if (!hasActiveFolds) {
        yTop = (block.startLine + 1) * _lineHeight;
      } else {
        yTop = 0;
        for (int j = 0; j <= block.startLine; j++) {
          if (!_isLineFolded(j)) yTop += _lineHeight;
        }
      }
      
      double yBottom;
      if (!hasActiveFolds) {
        yBottom = (block.endLine - 1) * _lineHeight + _lineHeight;
      } else {
        yBottom = 0;
        for (int j = 0; j < block.endLine; j++) {
          if (!_isLineFolded(j)) yBottom += _lineHeight;
        }
      }
      
      final screenYTop = offset.dy + (innerPadding?.top ?? 0) + yTop - vscrollController.offset;
      final screenYBottom = offset.dy + (innerPadding?.top ?? 0) + yBottom - vscrollController.offset;
      
      if (screenYBottom < 0 || screenYTop > viewBottom - viewTop) continue;
      
      final screenGuideX = offset.dx
        + _gutterWidth
        + (innerPadding?.left ?? 0) 
        + block.guideX
        - hscrollController.offset;
      
      if (screenGuideX < offset.dx + _gutterWidth || screenGuideX > offset.dx + size.width) continue;
      
      final clampedYTop = screenYTop.clamp(0.0, viewBottom - viewTop);
      final clampedYBottom = screenYBottom.clamp(0.0, viewBottom - viewTop);
      
      canvas.drawLine(
        Offset(screenGuideX, clampedYTop),
        Offset(screenGuideX, clampedYBottom),
        guidePaint,
      );
    }
  }
  
  void _drawBracketHighlight(
    Canvas canvas, Offset offset, double viewTop, double viewBottom,
    int firstVisibleLine, int lastVisibleLine, double firstVisibleLineY,
    bool hasActiveFolds, Color textColor
  ) {
    final (bracket1, bracket2) = _getBracketPairAtCursor();
    if (bracket1 == null || bracket2 == null) return;
    
    final line1 = controller.getLineAtOffset(bracket1);
    final line2 = controller.getLineAtOffset(bracket2);
    
    if (line1 >= firstVisibleLine && line1 <= lastVisibleLine && 
        (!hasActiveFolds || !_isLineFolded(line1))) {
      _drawBracketBox(canvas, offset, bracket1, line1, hasActiveFolds, textColor);
    }
    
    if (line2 >= firstVisibleLine && line2 <= lastVisibleLine && 
        (!hasActiveFolds || !_isLineFolded(line2))) {
      _drawBracketBox(canvas, offset, bracket2, line2, hasActiveFolds, textColor);
    }
  }
  
  void _drawBracketBox(
    Canvas canvas, Offset offset, int bracketOffset, int lineIndex,
    bool hasActiveFolds, Color textColor
  ) {
    final lineStartOffset = controller.getLineStartOffset(lineIndex);
    final columnIndex = bracketOffset - lineStartOffset;
    
    String lineText;
    if (_lineTextCache.containsKey(lineIndex)) {
      lineText = _lineTextCache[lineIndex]!;
    } else {
      lineText = controller.getLineText(lineIndex);
      _lineTextCache[lineIndex] = lineText;
    }
    
    if (columnIndex < 0 || columnIndex >= lineText.length) return;
    
    ui.Paragraph para;
    if (_paragraphCache.containsKey(lineIndex)) {
      para = _paragraphCache[lineIndex]!;
    } else {
      para = _buildParagraph(lineText);
      _paragraphCache[lineIndex] = para;
    }
    
    final boxes = para.getBoxesForRange(columnIndex, columnIndex + 1);
    if (boxes.isEmpty) return;
    
    final box = boxes.first;
    
    double lineY;
    if (!hasActiveFolds) {
      lineY = lineIndex * _lineHeight;
    } else {
      lineY = 0;
      for (int i = 0; i < lineIndex; i++) {
        if (!_isLineFolded(i)) lineY += _lineHeight;
      }
    }
    
    final screenX = offset.dx
      + _gutterWidth
      + (innerPadding?.left ?? 0) 
      + box.left
      - hscrollController.offset;
    final screenY = offset.dy
      + (innerPadding?.top ?? 0) 
      + lineY
      - vscrollController.offset;
    
    final bracketRect = Rect.fromLTWH(
      screenX - 1,
      screenY,
      box.right - box.left + 2,
      _lineHeight
    );
    
    _bracketHighlightPainter.color = textColor;
    canvas.drawRect(bracketRect, _bracketHighlightPainter);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChange);
    super.dispose();
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent && event.buttons == kPrimaryButton) {
      focusNode.requestFocus();
      final localPosition = event.localPosition;
      
      if (enableFolding && enableGutter && localPosition.dx < _gutterWidth) {
        final clickY = localPosition.dy + vscrollController.offset - (innerPadding?.top ?? 0);
        
        final hasActiveFolds = _foldRanges.any((f) => f.isFolded);
        int clickedLine;
        
        if (!hasActiveFolds) {
          clickedLine = (clickY / _lineHeight).floor().clamp(0, controller.lineCount - 1);
        } else {
          clickedLine = 0;
          double currentY = 0;
          for (int i = 0; i < controller.lineCount; i++) {
            if (_isLineFolded(i)) continue;
            
            if (clickY >= currentY && clickY < currentY + _lineHeight) {
              clickedLine = i;
              break;
            }
            currentY += _lineHeight;
          }
        }
        
        final foldRange = _getFoldRangeAtLine(clickedLine);
        if (foldRange != null) {
          _toggleFold(foldRange);
          return;
        }
        return;
      }
      
      final contentPosition = Offset(
        localPosition.dx - _gutterWidth - (innerPadding?.left ?? 0) + hscrollController.offset,
        localPosition.dy - (innerPadding?.top ?? 0) + vscrollController.offset,
      );
      final textOffset = _getTextOffsetFromPosition(contentPosition);
      controller.selection = TextSelection.collapsed(offset: textOffset);
    }
  }
}
