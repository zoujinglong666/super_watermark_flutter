import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class WatermarkPainter {
  static void drawWatermark({
    required Canvas canvas,
    required Size size,
    required ui.Image? backgroundImage,
    required String watermarkText,
    required double fontSize,
    required Color textColor,
    required double opacity,
    required double rotation,
    required Offset position,
    required String fontFamily,
    required FontWeight fontWeight,
    double spacing = 50.0,
  }) {
    // 绘制背景图片
    if (backgroundImage != null) {
      final paint = Paint();
      canvas.drawImageRect(
        backgroundImage,
        Rect.fromLTWH(0, 0, backgroundImage.width.toDouble(), backgroundImage.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
    }

    // 绘制平铺水印文字
    if (watermarkText.isNotEmpty) {
      final textStyle = TextStyle(
        color: textColor.withOpacity(opacity),
        fontSize: fontSize,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
      );

      final textSpan = TextSpan(
        text: watermarkText,
        style: textStyle,
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // 绘制平铺水印
      _drawTileWatermark(canvas, textPainter, size, rotation, spacing);
    }
  }

  static void _drawTileWatermark(Canvas canvas, TextPainter textPainter, Size size, double rotation, double spacing) {
    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    final rotationRad = rotation * 3.14159 / 180;

    // 计算旋转后文本的边界框
    final cosVal = cos(rotationRad).abs();
    final sinVal = sin(rotationRad).abs();
    final rotatedWidth = textWidth * cosVal + textHeight * sinVal;
    final rotatedHeight = textWidth * sinVal + textHeight * cosVal;

    // 计算水印间距
    final baseVerticalSpacing = spacing;
    final userHorizontalSpacing = spacing * 1.0;
    
    final minHorizontalSpacing = rotatedWidth + 20;
    final minVerticalSpacing = rotatedHeight + 15;
    
    final horizontalSpacing = (minHorizontalSpacing > userHorizontalSpacing) 
        ? minHorizontalSpacing 
        : userHorizontalSpacing;
    final verticalSpacing = (minVerticalSpacing > baseVerticalSpacing) 
        ? minVerticalSpacing 
        : baseVerticalSpacing;

    // 计算网格数量
    final cols = ((size.width + rotatedWidth * 2) / horizontalSpacing).ceil() + 1;
    final rows = ((size.height + rotatedHeight * 2) / verticalSpacing).ceil() + 1;

    // 计算起始位置，确保居中对齐
    final totalWidth = (cols - 1) * horizontalSpacing;
    final totalHeight = (rows - 1) * verticalSpacing;
    final startX = (size.width - totalWidth) / 2;
    final startY = (size.height - totalHeight) / 2;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        // 计算精确位置
        double x = startX + col * horizontalSpacing;
        double y = startY + row * verticalSpacing;
        
        // 智能交错：只有在间距足够时才启用
        final enableStagger = horizontalSpacing > minHorizontalSpacing * 1.2;
        if (enableStagger && row % 2 == 1) {
          x += horizontalSpacing * 0.5;
        }

        // 检查是否在图片区域内
        if (x >= -rotatedWidth/2 && 
            x <= size.width - rotatedWidth/2 &&
            y >= -rotatedHeight/2 && 
            y <= size.height - rotatedHeight/2) {
          
          canvas.save();
          canvas.translate(x + textWidth / 2, y + textHeight / 2);
          canvas.rotate(rotationRad);
          canvas.translate(-textWidth / 2, -textHeight / 2);
          textPainter.paint(canvas, Offset.zero);
          canvas.restore();
        }
      }
    }
  }

  static Future<ui.Image> createWatermarkImage({
    required Size size,
    required ui.Image? backgroundImage,
    required String watermarkText,
    required double fontSize,
    required Color textColor,
    required double opacity,
    required double rotation,
    required Offset position,
    required String fontFamily,
    required FontWeight fontWeight,
    double spacing = 50.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    drawWatermark(
      canvas: canvas,
      size: size,
      backgroundImage: backgroundImage,
      watermarkText: watermarkText,
      fontSize: fontSize,
      textColor: textColor,
      opacity: opacity,
      rotation: rotation,
      position: position,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      spacing: spacing,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    picture.dispose();

    return image;
  }
}