import 'package:flutter/material.dart' show Icons, IconData, TextStyle, Color;

/// Style configuration for the code selection
class CodeSelectionStyle {
  final Color selectionColor;
  final Color? cursorColor;
  final Color cursorBubbleColor;

  const CodeSelectionStyle({
    this.selectionColor = const Color(0x40448AFF),
    this.cursorColor,
    this.cursorBubbleColor = const Color(0xFF448AFF),
  });
}

/// Style configuration for the gutter (line numbers area)
class GutterStyle {
  final double? gutterWidth;
  final TextStyle? lineNumberStyle;
  final Color? backgroundColor;
  final Color? foldedIconColor;
  final Color? unfoldedIconColor;
  final IconData foldedIcon;
  final IconData unfoldedIcon;

  const GutterStyle({
    this.gutterWidth,
    this.lineNumberStyle,
    this.backgroundColor,
    this.foldedIconColor,
    this.unfoldedIconColor,
    this.foldedIcon = Icons.chevron_right,
    this.unfoldedIcon = Icons.expand_more,
  });
}

/// Represents a foldable code region
class FoldRange {
  final int startIndex;
  final int endIndex;
  bool isFolded = false;
  List<FoldRange> originallyFoldedChildren = [];

  FoldRange(this.startIndex, this.endIndex);

  void addOriginallyFoldedChild(FoldRange child) {
    if (!originallyFoldedChildren.contains(child)) {
      originallyFoldedChildren.add(child);
    }
  }

  void clearOriginallyFoldedChildren() {
    originallyFoldedChildren.clear();
  }

  bool containsLine(int line) {
    return line > startIndex && line <= endIndex;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoldRange && 
           other.startIndex == startIndex && 
           other.endIndex == endIndex;
  }
  
  @override
  int get hashCode => startIndex.hashCode ^ endIndex.hashCode;
}
