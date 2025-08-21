import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum WatermarkMode {
  tile,
  diagonal,
}

class WatermarkPreview extends StatefulWidget {
  final File image;
  final String watermarkText;
  final double fontSize;
  final Color textColor;
  final double opacity;
  final double rotation;
  final double? spacing;
  final WatermarkMode mode;
  final bool showLoadingIndicator;

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
    this.showLoadingIndicator = true,
  });

  @override
  State<WatermarkPreview> createState() => _WatermarkPreviewState();
}

class _WatermarkPreviewState extends State<WatermarkPreview> {
  ui.Image? _cachedImage;
  bool _isLoading = true;
  String? _lastImagePath;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(WatermarkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有当图片路径改变时才重新加载
    if (widget.image.path != _lastImagePath) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    try {
      _lastImagePath = widget.image.path;
      final image = await _loadImageFromFile(widget.image);
      if (mounted) {
        setState(() {
          _cachedImage = image;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isLoading) {
          if (widget.showLoadingIndicator) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
              ),
            );
          } else {
            // 不显示loading时，显示当前图片作为占位
            return Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: FileImage(widget.image),
                  fit: BoxFit.contain,
                ),
              ),
            );
          }
        }

        if (_cachedImage == null) {
          return const Center(
            child: Text('加载图片失败'),
          );
        }

        return Stack(
          children: [
            // 背景图片
            Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: FileImage(widget.image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // 水印层
            Positioned.fill(
              child: CustomPaint(
                painter: _UnifiedWatermarkPainter(
                  backgroundImage: _cachedImage!,
                  watermarkText: widget.watermarkText,
                  fontSize: widget.fontSize,
                  textColor: widget.textColor,
                  opacity: widget.opacity,
                  rotation: widget.rotation,
                  spacing: widget.spacing ?? _calculateDefaultSpacing(),
                  containerSize: Size(constraints.maxWidth, constraints.maxHeight),
                  mode: widget.mode,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _calculateDefaultSpacing() {
    return max(50.0, widget.fontSize * 2.5);
  }

  Future<ui.Image> _loadImageFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      // 重新抛出异常，让调用方处理
      rethrow;
    }
  }
}

class _UnifiedWatermarkPainter extends CustomPainter {
  final ui.Image backgroundImage;
  final String watermarkText;
  final double fontSize;
  final Color textColor;
  final double opacity;
  final double rotation;
  final double spacing;
  final Size containerSize;
  final WatermarkMode mode;

  _UnifiedWatermarkPainter({
    required this.backgroundImage,
    required this.watermarkText,
    required this.fontSize,
    required this.textColor,
    required this.opacity,
    required this.rotation,
    required this.spacing,
    required this.containerSize,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (watermarkText.isEmpty) return;

    // 计算图片在容器中的实际显示区域
    final imageRect = _calculateImageDisplayRect();
    
    // 只在图片区域内绘制水印
    canvas.clipRect(imageRect);

    final textPainter = TextPainter(
      text: TextSpan(
        text: watermarkText,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor.withOpacity(opacity),
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

        // 检查是否在图片区域内 - 使用与导出相同的边界检查逻辑
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

  void _drawDiagonalWatermark(Canvas canvas, TextPainter textPainter, Rect imageRect) {
    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    
    // 对角线模式的间距
    final diagonalSpacing = spacing * 1.2;
    final rotationRad = rotation * pi / 180;
    
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

  bool _isPositionInImageRect(double x, double y, double textWidth, double textHeight, Rect imageRect) {
    // 检查文本是否与图片区域有交集
    final textRect = Rect.fromLTWH(x, y, textWidth, textHeight);
    return imageRect.overlaps(textRect);
  }

  Rect _calculateImageDisplayRect() {
    // 计算图片按 BoxFit.contain 在容器中的实际显示区域
    final imageSize = Size(backgroundImage.width.toDouble(), backgroundImage.height.toDouble());
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

  @override
  bool shouldRepaint(covariant _UnifiedWatermarkPainter oldDelegate) {
    return oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.watermarkText != watermarkText ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.textColor != textColor ||
        oldDelegate.opacity != opacity ||
        oldDelegate.rotation != rotation ||
        oldDelegate.spacing != spacing ||
        oldDelegate.containerSize != containerSize ||
        oldDelegate.mode != mode;
  }
}
