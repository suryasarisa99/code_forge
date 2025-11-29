import 'dart:math' as math;

import 'controller.dart';

import 'package:code_forge/scroll.dart';
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

  const CodeForge({
    super.key,
    this.controller,
    this.innerPadding,
    this.verticalScrollController,
    this.horizontalScrollController,
    this.focusNode,
    this.readOnly = false
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
                      return KeyboardListener(
                        focusNode: _focusNode,
                        child: _CodeField(
                          _controller,
                          widget.innerPadding,
                          _vscrollController,
                          _hscrollController,
                          _focusNode,
                          widget.readOnly,
                          _caretBlinkController,
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

  const _CodeField(
    this.controller,
    this.innerPadding,
    this.vscrollController,
    this.hscrollController,
    this.focusNode,
    this.readOnly,
    this.caretBlinkController,
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

  List<String> _lines = [];
  final List<double> _lineTops = [], _lineHeights = [];
  final List<int> _lineStartOffsets = [];
  final Paint _caretPainter = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill;
  
    final Map<int, double> _lineWidthCache = {};
  
  _CodeFieldRenderer(
    this.controller,
    this.innerPadding,
    this.vscrollController,
    this.hscrollController,
    this.focusNode,
    this.readOnly,
    this.caretBlinkController,
  ) {
    _lines = controller.lines;     vscrollController.addListener(markNeedsPaint);
    hscrollController.addListener(markNeedsPaint);
    caretBlinkController.addListener(markNeedsPaint);
    
        controller.addListener(_onControllerChange);
  }
  
  void _onControllerChange() {
    if (controller.selectionOnly) {
      controller.selectionOnly = false;
      markNeedsPaint();
      return;
    }
    
    final dirtyRegion = controller.dirtyRegion;
    
    if (dirtyRegion != null) {
      final newLines = controller.lines;
      final lineDelta = newLines.length - _lines.length;
      if (lineDelta == 0) {
        _updateLineOffsetsIncrementally(dirtyRegion, newLines, false);
        _invalidateWidthCache(dirtyRegion, newLines);
        _lines = newLines;
        controller.clearDirtyRegion();
        markNeedsPaint();
      } else if (_lineTops.isNotEmpty && _lineStartOffsets.isNotEmpty) {
        final affectedLine = _findLineByCharOffset(dirtyRegion.start);
        _updateLayoutIncrementally(affectedLine, lineDelta, newLines);
        _lines = newLines;
        controller.clearDirtyRegion();
        markNeedsPaint();
      } else {
                _lines = newLines;
        controller.clearDirtyRegion();
        markNeedsLayout();
      }
    } else {
            _lines = controller.lines;
      markNeedsLayout();
    }
  }
  
  void _updateLayoutIncrementally(int affectedLine, int lineDelta, List<String> newLines) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    if (lineDelta > 0) {
            
    if (affectedLine < _lineHeights.length && affectedLine < newLines.length) {
      final lineText = newLines[affectedLine];
      tp.text = TextSpan(text: lineText, style: const TextStyle(fontSize: 14));
      tp.layout(maxWidth: double.infinity);
      _lineHeights[affectedLine] = tp.height;
      _lineWidthCache[affectedLine] = tp.width;
    }
    for (int i = 0; i < lineDelta; i++) {
      final insertIdx = affectedLine + 1 + i;
      if (insertIdx <= newLines.length) {
        final lineText = insertIdx < newLines.length ? newLines[insertIdx] : '';
        tp.text = TextSpan(text: lineText, style: const TextStyle(fontSize: 14));
        tp.layout(maxWidth: double.infinity);
        final prevTop = insertIdx > 0 && insertIdx - 1 < _lineTops.length
          ? _lineTops[insertIdx - 1] : 0.0;
        final prevHeight = insertIdx > 0 && insertIdx - 1 < _lineHeights.length 
            ? _lineHeights[insertIdx - 1] : 0.0;
          
        _lineTops.insert(insertIdx, prevTop + prevHeight);
        _lineHeights.insert(insertIdx, tp.height);
        _lineStartOffsets.insert(insertIdx, 0);           
        _lineWidthCache[insertIdx] = tp.width;
      }
    }
      
    final heightDelta = lineDelta * (tp.height > 0 ? tp.height : 16.0);
      for (int i = affectedLine + 1 + lineDelta; i < _lineTops.length; i++) {
        _lineTops[i] += heightDelta;
      }
      
    } else if (lineDelta < 0) {
            final removeCount = -lineDelta;
      for (int i = 0; i < removeCount; i++) {
        final removeIdx = affectedLine + 1;
        if (removeIdx < _lineTops.length) {
          final removedHeight = _lineHeights[removeIdx];
          _lineTops.removeAt(removeIdx);
          _lineHeights.removeAt(removeIdx);
          if (removeIdx < _lineStartOffsets.length) {
            _lineStartOffsets.removeAt(removeIdx);
          }
          _lineWidthCache.remove(removeIdx);
          
          for (int j = removeIdx; j < _lineTops.length; j++) {
            _lineTops[j] -= removedHeight;
          }
        }
      }
      
      if (affectedLine < newLines.length) {
        final lineText = newLines[affectedLine];
        tp.text = TextSpan(text: lineText, style: const TextStyle(fontSize: 14));
        tp.layout(maxWidth: double.infinity);
        _lineWidthCache[affectedLine] = tp.width;
      }
    }
    
    _rebuildLineStartOffsets(newLines);
  }
  
  void _rebuildLineStartOffsets(List<String> lines) {
    _lineStartOffsets.clear();
    int charOffset = 0;
    for (int i = 0; i < lines.length; i++) {
      _lineStartOffsets.add(charOffset);
      charOffset += lines[i].length + 1;     }
  }
  
  void _updateLineOffsetsIncrementally(TextRange dirtyRegion, List<String> newLines, bool lineCountChanged) {
    if (_lineStartOffsets.isEmpty || lineCountChanged) {
      return;
    }
    
    final affectedLine = _findLineByCharOffset(dirtyRegion.start);
    final oldLineLength = affectedLine < _lines.length ? _lines[affectedLine].length : 0;
    final newLineLength = affectedLine < newLines.length ? newLines[affectedLine].length : 0;
    final delta = newLineLength - oldLineLength;
    
    if (delta == 0) return;
    for (int i = affectedLine + 1; i < _lineStartOffsets.length; i++) {
      _lineStartOffsets[i] += delta;
    }
  }
  
  void _invalidateWidthCache(TextRange dirtyRegion, List<String> newLines) {
    if (_lineStartOffsets.isEmpty) return;
    final affectedLine = _findLineByCharOffset(dirtyRegion.start);
    _lineWidthCache.remove(affectedLine);
  }

  int _findFirstVisibleLine(double viewTop) {
    if (_lineTops.isEmpty) return 0;
    int low = 0, high = _lineTops.length - 1, mid;
    while (low < high) {
      mid = (low + high) >> 1;
      if (_lineTops[mid] < viewTop) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low.clamp(0, _lineTops.length - 1);
  }

  int _findLastVisibleLine(double viewBottom) {
    if (_lineTops.isEmpty) return 0;
    int low = 0, high = _lineTops.length - 1, mid;
    while (low < high) {
      mid = (low + high + 1) >> 1;
      if (_lineTops[mid] <= viewBottom) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low.clamp(0, _lineTops.length - 1);
  }
  
  int _findLineByCharOffset(int charOffset) {
    if (_lineStartOffsets.isEmpty) return 0;
    
    int low = 0, high = _lineStartOffsets.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (_lineStartOffsets[mid] <= charOffset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low.clamp(0, _lines.length - 1);
  }
  
  int _findLineByYPosition(double y) {
    if (_lineTops.isEmpty) return 0;
    
    int low = 0, high = _lineTops.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (_lineTops[mid] <= y) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low.clamp(0, _lines.length - 1);
  }
  
  ({int lineIndex, int columnIndex, Offset offset, double height}) _getCaretInfo() {
    final cursorOffset = controller.selection.extentOffset;
    if (_lines.isEmpty || _lineStartOffsets.isEmpty) {
      return (lineIndex: 0, columnIndex: 0, offset: Offset.zero, height: 16.0);
    }
    
    final lineIndex = _findLineByCharOffset(cursorOffset);
    final lineStartOffset = _lineStartOffsets[lineIndex];
    final columnIndex = cursorOffset - lineStartOffset;
    final lineY = lineIndex < _lineTops.length ? _lineTops[lineIndex] : 0.0;
    final lineHeight = lineIndex < _lineHeights.length ? _lineHeights[lineIndex] : 16.0;
    final lineText = lineIndex < _lines.length ? _lines[lineIndex] : '';
    final tp = TextPainter(
      text: TextSpan(text: lineText, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    
    final caretOffsetInLine = tp.getOffsetForCaret(
      TextPosition(offset: columnIndex.clamp(0, lineText.length)),
      Rect.zero,
    );
    
    return (
      lineIndex: lineIndex,
      columnIndex: columnIndex,
      offset: Offset(caretOffsetInLine.dx, lineY),
      height: lineHeight,
    );
  }
  
  int _getTextOffsetFromPosition(Offset position) {
    if (_lines.isEmpty || _lineTops.isEmpty || _lineStartOffsets.isEmpty) return 0;
    final tappedLineIndex = _findLineByYPosition(position.dy);
    final lineText = _lines[tappedLineIndex];
    final tp = TextPainter(
      text: TextSpan(text: lineText, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
  
    final lineTop = _lineTops[tappedLineIndex];
    final localX = position.dx;
    final localY = position.dy - lineTop;
    final textPosition = tp.getPositionForOffset(Offset(localX, localY));
    final absoluteOffset = _lineStartOffsets[tappedLineIndex] + textPosition.offset;
    
    return absoluteOffset.clamp(0, controller.length);
  }

  @override
  void performLayout() {
    _lines = controller.lines;     _lineTops.clear();
    _lineHeights.clear();
    _lineStartOffsets.clear();
    
    double y = 0.0, maxLineWidth = 0.0;
    int charOffset = 0;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < _lines.length; i++) {
      _lineStartOffsets.add(charOffset);
      charOffset += _lines[i].length + 1;       
      double lineWidth;
      if (_lineWidthCache.containsKey(i)) {
        lineWidth = _lineWidthCache[i]!;
        tp.text = TextSpan(text: _lines[i], style: const TextStyle(fontSize: 14));
        tp.layout(maxWidth: double.infinity);
      } else {
        tp.text = TextSpan(text: _lines[i], style: const TextStyle(fontSize: 14));
        tp.layout(maxWidth: double.infinity);
        lineWidth = tp.width;
        _lineWidthCache[i] = lineWidth;
      }
      
      maxLineWidth = math.max(maxLineWidth, lineWidth);
      _lineTops.add(y);
      _lineHeights.add(tp.height);
      y += tp.height;
    }

    final contentWidth = maxLineWidth + (innerPadding?.horizontal ?? 0);  
    final contentHeight = y + (innerPadding?.vertical ?? 0);

    size = constraints.constrain(Size(contentWidth, contentHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final canvas = context.canvas;
    final viewTop = vscrollController.offset;
    final viewBottom = viewTop + vscrollController.position.viewportDimension;
    final firstVisibleLine = _findFirstVisibleLine(viewTop);
    final lastVisibleLine = _findLastVisibleLine(viewBottom);

    canvas.save();
    canvas.drawPaint(
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
    );

    for (int i = firstVisibleLine; i <= lastVisibleLine && i < _lines.length; i++) {
      if (i >= _lineTops.length) break;

      final contentTop = _lineTops[i];
      tp.text = TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 14),
        text: _lines[i]
      );
      tp.layout(maxWidth: double.infinity);
      tp.paint(
        canvas,
        offset + Offset(
          (innerPadding?.left ?? innerPadding?.right ?? 0) - hscrollController.offset,
          (innerPadding?.top ?? innerPadding?.bottom ?? 0) + contentTop - vscrollController.offset
        )
      );
    }
    
    if (focusNode.hasFocus && caretBlinkController.value > 0.5) {
      final caretInfo = _getCaretInfo();
      
      final caretX = (innerPadding?.left ?? 0)
        + caretInfo.offset.dx
        - hscrollController.offset;
      final caretY = (innerPadding?.top ?? 0)
        + caretInfo.offset.dy
        - vscrollController.offset;

      canvas.drawRect(
        Rect.fromLTWH(
          caretX,
          caretY,
          1.5,
          caretInfo.height
        ),
        _caretPainter,
      );
    }

    canvas.restore();
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
      final contentPosition = Offset(
        localPosition.dx - (innerPadding?.left ?? 0) + hscrollController.offset,
        localPosition.dy - (innerPadding?.top ?? 0) + vscrollController.offset,
      );
      final textOffset = _getTextOffsetFromPosition(contentPosition);
      controller.selection = TextSelection.collapsed(offset: textOffset);
    }
  }
}