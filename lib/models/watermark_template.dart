import 'dart:convert';
import 'package:flutter/material.dart';

class WatermarkTemplate {
  final String id;
  final String name;
  final String text;
  final double fontSize;
  final Color textColor;
  final double opacity;
  final double rotation;
  final double spacing;
  final WatermarkPosition position;
  final DateTime createdAt;
  final bool isDefault;

  WatermarkTemplate({
    required this.id,
    required this.name,
    required this.text,
    required this.fontSize,
    required this.textColor,
    required this.opacity,
    required this.rotation,
    required this.spacing,
    required this.position,
    required this.createdAt,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'text': text,
      'fontSize': fontSize,
      'textColor': textColor.value,
      'opacity': opacity,
      'rotation': rotation,
      'spacing': spacing,
      'position': position.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isDefault': isDefault,
    };
  }

  factory WatermarkTemplate.fromMap(Map<String, dynamic> map) {
    return WatermarkTemplate(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      text: map['text'] ?? '',
      fontSize: map['fontSize']?.toDouble() ?? 12.0,
      textColor: Color(map['textColor'] ?? Colors.red.value),
      opacity: map['opacity']?.toDouble() ?? 0.7,
      rotation: map['rotation']?.toDouble() ?? -30.0,
      spacing: map['spacing']?.toDouble() ?? 50.0,
      position: WatermarkPosition.values[map['position'] ?? 0],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      isDefault: map['isDefault'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory WatermarkTemplate.fromJson(String source) =>
      WatermarkTemplate.fromMap(json.decode(source));

  WatermarkTemplate copyWith({
    String? id,
    String? name,
    String? text,
    double? fontSize,
    Color? textColor,
    double? opacity,
    double? rotation,
    double? spacing,
    WatermarkPosition? position,
    DateTime? createdAt,
    bool? isDefault,
  }) {
    return WatermarkTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      spacing: spacing ?? this.spacing,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

enum WatermarkPosition {
  tile,      // 平铺
  topLeft,   // 左上角
  topRight,  // 右上角
  bottomLeft, // 左下角
  bottomRight, // 右下角
  center,    // 居中
  topCenter, // 上方居中
  bottomCenter, // 下方居中
}

extension WatermarkPositionExtension on WatermarkPosition {
  String get displayName {
    switch (this) {
      case WatermarkPosition.tile:
        return '平铺';
      case WatermarkPosition.topLeft:
        return '左上角';
      case WatermarkPosition.topRight:
        return '右上角';
      case WatermarkPosition.bottomLeft:
        return '左下角';
      case WatermarkPosition.bottomRight:
        return '右下角';
      case WatermarkPosition.center:
        return '居中';
      case WatermarkPosition.topCenter:
        return '上方居中';
      case WatermarkPosition.bottomCenter:
        return '下方居中';
    }
  }

  IconData get icon {
    switch (this) {
      case WatermarkPosition.tile:
        return Icons.grid_3x3;
      case WatermarkPosition.topLeft:
        return Icons.north_west;
      case WatermarkPosition.topRight:
        return Icons.north_east;
      case WatermarkPosition.bottomLeft:
        return Icons.south_west;
      case WatermarkPosition.bottomRight:
        return Icons.south_east;
      case WatermarkPosition.center:
        return Icons.center_focus_strong;
      case WatermarkPosition.topCenter:
        return Icons.north;
      case WatermarkPosition.bottomCenter:
        return Icons.south;
    }
  }
}