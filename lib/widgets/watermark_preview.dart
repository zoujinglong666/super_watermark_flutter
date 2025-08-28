import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../models/watermark_template.dart';

enum WatermarkMode {
  tile,
  diagonal,
}

class WatermarkPreview extends StatelessWidget {
  final File image;
  final String watermarkText;
  final double fontSize;
  final Color textColor;
  final double opacity;
  final double rotation;
  final double? spacing;
  final WatermarkMode mode;
  final WatermarkPosition position;
  final double imageRotation;

  const WatermarkPreview({
    super.key,
    required this.image,
    required this.watermarkText,
    this.fontSize = 24,
    this.textColor = Colors.red,
    this.opacity = 0.7,
    this.rotation = -30,
    this.spacing,
    this.mode = WatermarkMode.tile,
    this.position = WatermarkPosition.tile,
    this.imageRotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _loadImageFromFile(image),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(
            child: Text('加载图片失败'),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // 背景图片
                Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(image),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // 水印层
                Positioned.fill(
                  child: CustomPaint(
                    painter: WatermarkPainter(
                      text: watermarkText,
                      fontSize: fontSize,
                      textColor: textColor.withOpacity(opacity),
                      rotation: rotation,
                      spacing: spacing ?? _calculateDefaultSpacing(),
                      mode: mode,
                      position: position,
                      imageSize: Size(snapshot.data!.width.toDouble(), snapshot.data!.height.toDouble()),
                      containerSize: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double _calculateDefaultSpacing() {
    return max(80.0, fontSize * 3.5);
  }

  Future<ui.Image> _loadImageFromFile(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class WatermarkPainter extends CustomPainter {
  final String text;
  final double fontSize;
  final Color textColor;
  final double rotation;
  final double spacing;
  final WatermarkMode mode;
  final WatermarkPosition position;
  final Size imageSize;
  final Size containerSize;

  WatermarkPainter({
    required this.text,
    required this.fontSize,
    required this.textColor,
    required this.rotation,
    required this.spacing,
    required this.mode,
    required this.position,
    required this.imageSize,
    required this.containerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    // 计算图片在容器中的实际显示区域
    final imageRect = _calculateImageDisplayRect();

    // 只在图片区域内绘制水印
    canvas.clipRect(imageRect);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // 根据位置模式绘制水印
    switch (position) {
      case WatermarkPosition.tile:
        _drawTileWatermark(canvas, textPainter, imageRect);
        break;
      case WatermarkPosition.topLeft:
        _drawFixedPositionWatermark(canvas, textPainter, imageRect, Alignment.topLeft);
        break;
      case WatermarkPosition.topRight:
        _drawFixedPositionWatermark(canvas, textPainter, imageRect, Alignment.topRight);
        break;
      case WatermarkPosition.bottomLeft:
        _drawFixedPositionWatermark(canvas, textPainter, imageRect, Alignment.bottomLeft);
        break;
      case WatermarkPosition.bottomRight:
        _drawFixedPositionWatermark(canvas, textPainter, imageRect, Alignment.bottomRight);
        break;
      case WatermarkPosition.center:
        _drawFixedPositionWatermark(canvas, textPainter, imageRect, Alignment.center);
        break;
      case WatermarkPosition.topCenter:
        _drawFixedPositionWatermark(canvas, textPainter, imageRect, Alignment.topCenter);
        break;
      case WatermarkPosition.bottomCenter:
        _drawFixedPositionWatermark(canvas, textPainter, imageRect, Alignment.bottomCenter);
        break;
    }
  }

  Rect _calculateImageDisplayRect() {
    // 计算图片按 BoxFit.contain 在容器中的实际显示区域
    final imageAspectRatio = imageSize.width / imageSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;

    double displayWidth, displayHeight;
    double offsetX = 0, offsetY = 0;

    if (imageAspectRatio > containerAspectRatio) {
      // 图片更宽，以宽度为准
      displayWidth = containerSize.width;
      displayHeight = containerSize.width / imageAspectRatio;
      offsetY = (containerSize.height - displayHeight) / 2;
    } else {
      // 图片更高，以高度为准
      displayHeight = containerSize.height;
      displayWidth = containerSize.height * imageAspectRatio;
      offsetX = (containerSize.width - displayWidth) / 2;
    }

    return Rect.fromLTWH(offsetX, offsetY, displayWidth, displayHeight);
  }

  void _drawTileWatermark(Canvas canvas, TextPainter textPainter, Rect imageRect) {
    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    final rotationRad = rotation * pi / 180;

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
    final cols = ((imageRect.width + rotatedWidth * 2) / horizontalSpacing).ceil() + 1;
    final rows = ((imageRect.height + rotatedHeight * 2) / verticalSpacing).ceil() + 1;

    // 计算起始位置，确保居中对齐
    final totalWidth = (cols - 1) * horizontalSpacing;
    final totalHeight = (rows - 1) * verticalSpacing;
    final startX = imageRect.left + (imageRect.width - totalWidth) / 2;
    final startY = imageRect.top + (imageRect.height - totalHeight) / 2;

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
        if (x >= imageRect.left - rotatedWidth/2 && 
            x <= imageRect.right - rotatedWidth/2 &&
            y >= imageRect.top - rotatedHeight/2 && 
            y <= imageRect.bottom - rotatedHeight/2) {
          
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

  void _drawFixedPositionWatermark(Canvas canvas, TextPainter textPainter, Rect imageRect, Alignment alignment) {
    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    final rotationRad = rotation * pi / 180;

    // 计算水印位置
    double x, y;
    const margin = 20.0; // 边距

    switch (alignment) {
      case Alignment.topLeft:
        x = imageRect.left + margin;
        y = imageRect.top + margin;
        break;
      case Alignment.topRight:
        x = imageRect.right - textWidth - margin;
        y = imageRect.top + margin;
        break;
      case Alignment.bottomLeft:
        x = imageRect.left + margin;
        y = imageRect.bottom - textHeight - margin;
        break;
      case Alignment.bottomRight:
        x = imageRect.right - textWidth - margin;
        y = imageRect.bottom - textHeight - margin;
        break;
      case Alignment.center:
        x = imageRect.left + (imageRect.width - textWidth) / 2;
        y = imageRect.top + (imageRect.height - textHeight) / 2;
        break;
      case Alignment.topCenter:
        x = imageRect.left + (imageRect.width - textWidth) / 2;
        y = imageRect.top + margin;
        break;
      case Alignment.bottomCenter:
        x = imageRect.left + (imageRect.width - textWidth) / 2;
        y = imageRect.bottom - textHeight - margin;
        break;
      default:
        x = imageRect.left + (imageRect.width - textWidth) / 2;
        y = imageRect.top + (imageRect.height - textHeight) / 2;
    }

    // 绘制水印
    canvas.save();
    canvas.translate(x + textWidth / 2, y + textHeight / 2);
    canvas.rotate(rotationRad);
    canvas.translate(-textWidth / 2, -textHeight / 2);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WatermarkPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.textColor != textColor ||
        oldDelegate.rotation != rotation ||
        oldDelegate.spacing != spacing ||
        oldDelegate.mode != mode ||
        oldDelegate.position != position ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.containerSize != containerSize;
  }
}