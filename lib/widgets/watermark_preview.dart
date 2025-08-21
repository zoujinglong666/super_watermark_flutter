import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final Size imageSize;
  final Size containerSize;

  WatermarkPainter({
    required this.text,
    required this.fontSize,
    required this.textColor,
    required this.rotation,
    required this.spacing,
    required this.mode,
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

    // 根据模式绘制水印
    switch (mode) {
      case WatermarkMode.tile:
        _drawTileWatermark(canvas, textPainter, imageRect);
        break;
      case WatermarkMode.diagonal:
        _drawDiagonalWatermark(canvas, textPainter, imageRect);
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
    
    // 计算水印间距 - 主要控制上下间距
    final verticalSpacing = spacing; // 垂直间距由用户直接控制
    final horizontalSpacing = spacing * 1.0; // 水平间距为垂直间距的2倍
    
    // 计算需要绘制的行数和列数（扩展边界以确保完全覆盖）
    final rotationRad = rotation * pi / 180;
    final expandedWidth = imageRect.width + textWidth * 2;
    final expandedHeight = imageRect.height + textHeight * 2;
    
    final cols = (expandedWidth / horizontalSpacing).ceil() + 2;
    final rows = (expandedHeight / verticalSpacing).ceil() + 2;
    
    // 起始偏移，确保水印居中分布
    final startX = imageRect.left - textWidth;
    final startY = imageRect.top - textHeight;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        // 计算基础位置
        double x = startX + col * horizontalSpacing;
        double y = startY + row * verticalSpacing;
        
        // 交错排列，让水印更自然
        if (row % 2 == 1) {
          x += horizontalSpacing * 0.5;
        }
        
        // 添加微小的随机偏移，让水印看起来更自然
        final randomOffset = _getRandomOffset(row, col);
        x += randomOffset.dx;
        y += randomOffset.dy;

        // 检查是否在图片区域内
        if (_isPositionInImageRect(x, y, textWidth, textHeight, imageRect)) {
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

  void _drawDiagonalWatermark(Canvas canvas, TextPainter textPainter, Rect imageRect) {
    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    
    // 对角线模式的间距
    final diagonalSpacing = spacing * 1.2;
    final rotationRad = rotation * pi / 180;
    
    // 计算对角线方向的向量
    final cos45 = cos(pi / 4);
    final sin45 = sin(pi / 4);
    
    final expandedWidth = imageRect.width + textWidth * 2;
    final expandedHeight = imageRect.height + textHeight * 2;
    
    final diagonalLength = sqrt(expandedWidth * expandedWidth + expandedHeight * expandedHeight);
    final numDiagonals = (diagonalLength / diagonalSpacing).ceil();
    
    for (int i = 0; i < numDiagonals; i++) {
      // 主对角线
      _drawDiagonalLine(canvas, textPainter, imageRect, i * diagonalSpacing, rotationRad, true);
      // 反对角线
      _drawDiagonalLine(canvas, textPainter, imageRect, i * diagonalSpacing, rotationRad, false);
    }
  }

  void _drawDiagonalLine(Canvas canvas, TextPainter textPainter, Rect imageRect, 
                        double offset, double rotationRad, bool isMainDiagonal) {
    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    final lineSpacing = spacing * 0.6;
    
    // 计算对角线上的点
    final startX = imageRect.left - textWidth;
    final startY = imageRect.top - textHeight;
    final endX = imageRect.right + textWidth;
    final endY = imageRect.bottom + textHeight;
    
    if (isMainDiagonal) {
      // 从左上到右下的对角线
      double currentX = startX + offset;
      double currentY = startY;
      
      while (currentX < endX && currentY < endY) {
        if (_isPositionInImageRect(currentX, currentY, textWidth, textHeight, imageRect)) {
          canvas.save();
          canvas.translate(currentX + textWidth / 2, currentY + textHeight / 2);
          canvas.rotate(rotationRad);
          canvas.translate(-textWidth / 2, -textHeight / 2);
          textPainter.paint(canvas, Offset.zero);
          canvas.restore();
        }
        
        currentX += lineSpacing;
        currentY += lineSpacing;
      }
    } else {
      // 从右上到左下的对角线
      double currentX = endX - offset;
      double currentY = startY;
      
      while (currentX > startX && currentY < endY) {
        if (_isPositionInImageRect(currentX, currentY, textWidth, textHeight, imageRect)) {
          canvas.save();
          canvas.translate(currentX + textWidth / 2, currentY + textHeight / 2);
          canvas.rotate(rotationRad);
          canvas.translate(-textWidth / 2, -textHeight / 2);
          textPainter.paint(canvas, Offset.zero);
          canvas.restore();
        }
        
        currentX -= lineSpacing;
        currentY += lineSpacing;
      }
    }
  }

  Offset _getRandomOffset(int row, int col) {
    // 使用行列作为种子，确保每次绘制的随机偏移都一致
    final random = Random((row * 1000 + col).hashCode);
    final maxOffset = fontSize * 0.1; // 最大偏移为字体大小的10%
    return Offset(
      (random.nextDouble() - 0.5) * maxOffset,
      (random.nextDouble() - 0.5) * maxOffset,
    );
  }

  bool _isPositionInImageRect(double x, double y, double textWidth, double textHeight, Rect imageRect) {
    // 检查文本是否与图片区域有交集
    final textRect = Rect.fromLTWH(x, y, textWidth, textHeight);
    return imageRect.overlaps(textRect);
  }

  @override
  bool shouldRepaint(covariant WatermarkPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.textColor != textColor ||
        oldDelegate.rotation != rotation ||
        oldDelegate.spacing != spacing ||
        oldDelegate.mode != mode ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.containerSize != containerSize;
  }
}