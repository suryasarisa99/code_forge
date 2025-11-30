import 'dart:ui' as ui;

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
  final TextStyle? textStyle;

  const CodeForge({
    super.key,
    this.controller,
    this.innerPadding,
    this.verticalScrollController,
    this.horizontalScrollController,
    this.focusNode,
    this.readOnly = false,
    this.textStyle,
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
                          widget.textStyle,
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

  const _CodeField(
    this.controller,
    this.innerPadding,
    this.vscrollController,
    this.hscrollController,
    this.focusNode,
    this.readOnly,
    this.caretBlinkController,
    this.textStyle,
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

  late final double _lineHeight;
  
  final Paint _caretPainter = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill;

  final Map<int, double> _lineWidthCache = {};
  final Map<int, String> _lineTextCache = {};
  int _cachedLineCount = 0;

  final Map<int, ui.Paragraph> _paragraphCache = {};
  
  int _cachedCaretOffset = -1;
  int _cachedCaretLine = 0;
  int _cachedCaretLineStart = 0;
  
  late final ui.ParagraphStyle _paragraphStyle;
  late final ui.TextStyle _uiTextStyle;
  
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
  ) {
    final fontSize = textStyle?.fontSize ?? 14.0;
    final fontFamily = textStyle?.fontFamily;
    final color = textStyle?.color ?? Colors.black;
    final lineHeightMultiplier = textStyle?.height ?? 1.2;
    
    _lineHeight = fontSize * lineHeightMultiplier;
    
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

  void _onControllerChange() {
    if (controller.selectionOnly) {
      controller.selectionOnly = false;
      markNeedsPaint();
      return;
    }
    
    if (controller.bufferNeedsRepaint) {
      controller.bufferNeedsRepaint = false;
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
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  int _findFirstVisibleLine(double viewTop) {
    final lineCount = controller.lineCount;
    if (lineCount == 0) return 0;
    return (viewTop / _lineHeight).floor().clamp(0, lineCount - 1);
  }

  int _findLastVisibleLine(double viewBottom) {
    final lineCount = controller.lineCount;
    if (lineCount == 0) return 0;
    return (viewBottom / _lineHeight).ceil().clamp(0, lineCount - 1);
  }

  int _findLineByYPosition(double y) {
    final lineCount = controller.lineCount;
    if (lineCount == 0) return 0;
    return (y / _lineHeight).floor().clamp(0, lineCount - 1);
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

    final tappedLineIndex = _findLineByYPosition(position.dy);

    String lineText;
    if (_lineTextCache.containsKey(tappedLineIndex)) {
      lineText = _lineTextCache[tappedLineIndex]!;
    } else {
      lineText = controller.getLineText(tappedLineIndex);
      _lineTextCache[tappedLineIndex] = lineText;
      _paragraphCache.remove(tappedLineIndex);
    }

    // Use Paragraph to find position from tap coordinates
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
    final contentHeight = lineCount * _lineHeight + (innerPadding?.vertical ?? 0);

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
    
    final bufferActive = controller.isBufferActive;
    final bufferLineIndex = controller.bufferLineIndex;
    final bufferLineText = controller.bufferLineText;

    canvas.save();
    canvas.drawRect(offset & size, Paint()..color = Colors.white);

    for (int i = firstVisibleLine; i <= lastVisibleLine && i < lineCount; i++) {
      final contentTop = i * _lineHeight;
      
      ui.Paragraph paragraph;
      
      if (bufferActive && i == bufferLineIndex && bufferLineText != null) {
        paragraph = _buildParagraph(bufferLineText);
      } else {
        if (_paragraphCache.containsKey(i)) {
          paragraph = _paragraphCache[i]!;
        } else {
          String lineText;
          if (_lineTextCache.containsKey(i)) {
            lineText = _lineTextCache[i]!;
          } else {
            lineText = controller.getLineText(i);
            _lineTextCache[i] = lineText;
          }
          paragraph = _buildParagraph(lineText);
          _paragraphCache[i] = paragraph;
        }
      }

      canvas.drawParagraph(
        paragraph,
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
