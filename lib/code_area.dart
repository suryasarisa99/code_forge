import 'dart:math';

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
                        onKeyEvent: (value) {
                          if(value is KeyDownEvent){
                            switch (value.logicalKey) {
                              case LogicalKeyboardKey.backspace:
                                //TODO: implement backspace
                                break;
                              case LogicalKeyboardKey.arrowDown: break;
                              case LogicalKeyboardKey.arrowUp: break;
                              case LogicalKeyboardKey.arrowRight: break;
                              case LogicalKeyboardKey.arrowLeft: break;
                              default:
                            }
                          }
                        },
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

  static const double _fixedLineHeight = 16.8;
  final Paint _caretPainter = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill;

  final Map<int, double> _lineWidthCache = {};
  final Map<int, String> _lineTextCache = {};
  int _cachedLineCount = 0;

  final Map<int, TextPainter> _tpCache = {};

  _CodeFieldRenderer(
    this.controller,
    this.innerPadding,
    this.vscrollController,
    this.hscrollController,
    this.focusNode,
    this.readOnly,
    this.caretBlinkController,
  ) {
    vscrollController.addListener(markNeedsPaint);
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
    final newLineCount = controller.lineCount;
    final lineCountChanged = newLineCount != _cachedLineCount;

    if (dirtyRegion != null) {
      final startLine = controller.getLineAtOffset(dirtyRegion.start);
      final endLine = controller.getLineAtOffset(max(0, dirtyRegion.end - 1));

      for (int i = startLine; i <= endLine; i++) {
        _lineWidthCache.remove(i);
        _lineTextCache.remove(i);
        _tpCache.remove(i);
      }

      controller.clearDirtyRegion();
    }

    if (lineCountChanged) {
      _cachedLineCount = newLineCount;
      _lineTextCache.clear();
      _tpCache.clear();
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  int _findFirstVisibleLine(double viewTop) {
    final lineCount = controller.lineCount;
    if (lineCount == 0) return 0;
    return (viewTop / _fixedLineHeight).floor().clamp(0, lineCount - 1);
  }

  int _findLastVisibleLine(double viewBottom) {
    final lineCount = controller.lineCount;
    if (lineCount == 0) return 0;
    return (viewBottom / _fixedLineHeight).ceil().clamp(0, lineCount - 1);
  }

  int _findLineByYPosition(double y) {
    final lineCount = controller.lineCount;
    if (lineCount == 0) return 0;
    return (y / _fixedLineHeight).floor().clamp(0, lineCount - 1);
  }

  ({int lineIndex, int columnIndex, Offset offset, double height}) _getCaretInfo() {
    final cursorOffset = controller.selection.extentOffset;
    final lineCount = controller.lineCount;
    if (lineCount == 0) {
      return (lineIndex: 0, columnIndex: 0, offset: Offset.zero, height: _fixedLineHeight);
    }

    final lineIndex = controller.getLineAtOffset(cursorOffset);
    final lineStartOffset = controller.getLineStartOffset(lineIndex);
    final columnIndex = cursorOffset - lineStartOffset;
    final lineY = lineIndex * _fixedLineHeight;

    String lineText;
    if (_lineTextCache.containsKey(lineIndex)) {
      lineText = _lineTextCache[lineIndex]!;
    } else {
      lineText = controller.getLineText(lineIndex);
      _lineTextCache[lineIndex] = lineText;
      _tpCache.remove(lineIndex);
    }

    TextPainter tp;
    if (_tpCache.containsKey(lineIndex)) {
      tp = _tpCache[lineIndex]!;
    } else {
      tp = TextPainter(textDirection: TextDirection.ltr);
      tp.text = TextSpan(text: lineText, style: const TextStyle(fontSize: 14));
      tp.layout();
      _tpCache[lineIndex] = tp;
    }

    final caretOffsetInLine = tp.getOffsetForCaret(
      TextPosition(offset: columnIndex.clamp(0, lineText.length)),
      Rect.zero,
    );

    return (
      lineIndex: lineIndex,
      columnIndex: columnIndex,
      offset: Offset(caretOffsetInLine.dx, lineY),
      height: _fixedLineHeight,
    );
  }

  int _getTextOffsetFromPosition(Offset position) {
    final lineCount = controller.lineCount;
    if (lineCount == 0) return 0;

    final tappedLineIndex = _findLineByYPosition(position.dy);

    String lineText;
    if (_lineTextCache.containsKey(tappedLineIndex)) {
      lineText = _lineTextCache[tappedLineIndex]!;
    } else {
      lineText = controller.getLineText(tappedLineIndex);
      _lineTextCache[tappedLineIndex] = lineText;
      _tpCache.remove(tappedLineIndex);
    }

    TextPainter tp;
    if (_tpCache.containsKey(tappedLineIndex)) {
      tp = _tpCache[tappedLineIndex]!;
    } else {
      tp = TextPainter(textDirection: TextDirection.ltr);
      tp.text = TextSpan(text: lineText, style: const TextStyle(fontSize: 14));
      tp.layout();
      _tpCache[tappedLineIndex] = tp;
    }

    final lineTop = tappedLineIndex * _fixedLineHeight;
    final localX = position.dx;
    final localY = position.dy - lineTop;
    final textPosition = tp.getPositionForOffset(Offset(localX, localY));
    final lineStartOffset = controller.getLineStartOffset(tappedLineIndex);
    final absoluteOffset = lineStartOffset + textPosition.offset;

    return absoluteOffset.clamp(0, controller.length);
  }

  @override
  void performLayout() {
    final lineCount = controller.lineCount;
    final contentHeight = lineCount * _fixedLineHeight + (innerPadding?.vertical ?? 0);

    const estimatedMaxWidth = 2000.0;
    final contentWidth = estimatedMaxWidth + (innerPadding?.horizontal ?? 0);

    size = constraints.constrain(Size(contentWidth, contentHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final viewTop = vscrollController.offset;
    final viewBottom = viewTop + vscrollController.position.viewportDimension;
    final lineCount = controller.lineCount;
    final firstVisibleLine = _findFirstVisibleLine(viewTop);
    final lastVisibleLine = _findLastVisibleLine(viewBottom);

    canvas.save();
    canvas.drawRect(offset & size, Paint()..color = Colors.white);

    for (int i = firstVisibleLine; i <= lastVisibleLine && i < lineCount; i++) {
      final contentTop = i * _fixedLineHeight;

      String lineText;
      if (_lineTextCache.containsKey(i)) {
        lineText = _lineTextCache[i]!;
      } else {
        lineText = controller.getLineText(i);
        _lineTextCache[i] = lineText;
        _tpCache.remove(i);
      }

      TextPainter tp;
      if (_tpCache.containsKey(i)) {
        tp = _tpCache[i]!;
      } else {
        tp = TextPainter(textDirection: TextDirection.ltr);
        tp.text = TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          text: lineText
        );
        tp.layout(maxWidth: double.infinity);
        _tpCache[i] = tp;
      }

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
