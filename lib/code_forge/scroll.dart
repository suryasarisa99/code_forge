import 'dart:math' as math;

import 'package:flutter/material.dart';

class CustomViewport extends TwoDimensionalViewport{
  const CustomViewport({
    super.key,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required TwoDimensionalChildBuilderDelegate super.delegate,
    required super.mainAxis
  });

  @override
  RenderTwoDimensionalViewport createRenderObject(BuildContext context) {
    return Render2DCodeField(
      horizontalOffset: horizontalOffset,
      horizontalAxisDirection: horizontalAxisDirection,
      verticalOffset: verticalOffset,
      verticalAxisDirection: verticalAxisDirection,
      delegate: delegate,
      mainAxis: mainAxis,
      childManager: context as TwoDimensionalChildManager
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderTwoDimensionalViewport renderObject) {
    renderObject   
      ..horizontalOffset = horizontalOffset
      ..horizontalAxisDirection = horizontalAxisDirection
      ..verticalOffset = verticalOffset
      ..verticalAxisDirection = verticalAxisDirection
      ..delegate = delegate
      ..mainAxis = mainAxis;
  }
  
}

class Render2DCodeField extends RenderTwoDimensionalViewport{
  Render2DCodeField({
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.delegate,
    required super.mainAxis,
    required super.childManager
  });

  @override
  void layoutChildSequence() {
    final child = buildOrObtainChildFor(ChildVicinity(xIndex: 0, yIndex: 0));

    if(child != null){
      child.layout(
        BoxConstraints(
          minHeight: 0,
          minWidth: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
        ),
        
        parentUsesSize: true
      );
      parentDataOf(child).layoutOffset = Offset.zero;

      verticalOffset.applyContentDimensions(
        0.0,
        math.max(0.0, child.size.height - viewportDimension.height),
      );
      horizontalOffset.applyContentDimensions(
        0.0,
        math.max(0.0, child.size.width - viewportDimension.width),
      );
    }
  }

}