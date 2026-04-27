import 'package:flutter/material.dart';
import 'dart:math' as math;

class CropArea {
  final Offset start;
  final Offset end;

  CropArea({
    required this.start,
    required this.end,
  });

  Rect get rect {
    final left = math.min(start.dx, end.dx);
    final top = math.min(start.dy, end.dy);
    final right = math.max(start.dx, end.dx);
    final bottom = math.max(start.dy, end.dy);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double get width => rect.width;
  double get height => rect.height;
  bool get isValid => width > 50 && height > 50;
}
