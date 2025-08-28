import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
  final double imageRotation; // 添加图片旋转角度参数
  final bool addDateWatermark; // 添加日期隐水印参数

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
    this.imageRotation = 0, // 默认为0度，不旋转
    this.addDateWatermark = false, // 默认不添加日期隐水印
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
                      addDateWatermark: addDateWatermark, // 传递日期隐水印参数
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
  final bool addDateWatermark; // 添加日期隐水印参数

  WatermarkPainter({
    required this.text,
    required this.fontSize,
    required this.textColor,
    required this.rotation,
    required this.spacing,
    required this.mode,
    required this.imageSize,
    required this.containerSize,
    this.addDateWatermark = false, // 默认不添加日期隐水印
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
    
    // 添加日期隐水印
    if (addDateWatermark) {
      _drawDateWatermark(canvas, imageRect);
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
//   void _drawTileWatermark(Canvas canvas, TextPainter textPainter, Rect imageRect) {
//     final textWidth = textPainter.width;
//     final textHeight = textPainter.height;
//     final rotationRad = rotation * pi / 180;
//
// // 计算旋转后文本的边界框
//     final cosVal = cos(rotationRad).abs();
//     final sinVal = sin(rotationRad).abs();
//     final rotatedWidth = textWidth * cosVal + textHeight * sinVal;
//     final rotatedHeight = textWidth * sinVal + textHeight * cosVal;
//
// // 计算水印间距 - 主要控制上下间距
//     final verticalSpacing = spacing; // 垂直间距由用户控制
//     final horizontalSpacing = spacing * 1.8; // 水平间距稍大一些
//
// // 计算网格数量，确保完全覆盖
//     final cols = ((imageRect.width + rotatedWidth * 2) / horizontalSpacing)
//         .ceil() + 1;
//     final rows = ((imageRect.height + rotatedHeight * 2) / verticalSpacing)
//         .ceil() + 1;
//
// // 计算起始位置，确保居中对齐
//     final totalWidth = (cols - 1) * horizontalSpacing;
//     final totalHeight = (rows - 1) * verticalSpacing;
//     final startX = imageRect.left + (imageRect.width - totalWidth) / 2;
//     final startY = imageRect.top + (imageRect.height - totalHeight) / 2;
//
//     for (int row = 0; row < rows; row++) {
//       for (int col = 0; col < cols; col++) {
// // 计算精确位置 - 规律网格，无随机偏移
//         double x = startX + col * horizontalSpacing;
//         double y = startY + row * verticalSpacing;
//
// // 检查是否在图片区域内（考虑旋转后的尺寸）
//         if (x >= imageRect.left - rotatedWidth / 2 &&
//             x <= imageRect.right - rotatedWidth / 2 &&
//             y >= imageRect.top - rotatedHeight / 2 &&
//             y <= imageRect.bottom - rotatedHeight / 2) {
//           canvas.save();
//           canvas.translate(x + textWidth / 2, y + textHeight / 2);
//           canvas.rotate(rotationRad);
//           canvas.translate(-textWidth / 2, -textHeight / 2);
//           textPainter.paint(canvas, Offset.zero);
//           canvas.restore();
//         }
//       }
//     }
//   }


  // 统一后的平铺水印绘制方法
// 同时用于预览（_drawTileWatermark）和导出（_drawTileWatermarkForExport）
  void _drawTileWatermark(
      Canvas canvas,
      TextPainter textPainter,
      Rect imageRect,
      ) {
    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    final rotationRad = rotation * pi / 180;

    // ===== 1. 计算旋转后文本的边界框 =====
    final cosVal = cos(rotationRad).abs();
    final sinVal = sin(rotationRad).abs();
    final rotatedWidth = textWidth * cosVal + textHeight * sinVal;
    final rotatedHeight = textWidth * sinVal + textHeight * cosVal;

    // ===== 2. 计算水印间距（调整为更密集） =====
    final baseVerticalSpacing = spacing * 0.8;         // 垂直间距减小20%
    final userHorizontalSpacing = spacing * 0.8;       // 水平间距也减小20%

    final minHorizontalSpacing = rotatedWidth + 10;    // 最小水平间距减小
    final minVerticalSpacing = rotatedHeight + 8;      // 最小垂直间距减小

    final horizontalSpacing =
    minHorizontalSpacing > userHorizontalSpacing
        ? minHorizontalSpacing
        : userHorizontalSpacing;
    final verticalSpacing = minVerticalSpacing > baseVerticalSpacing
        ? minVerticalSpacing
        : baseVerticalSpacing;

    // ===== 3. 计算网格数量 =====
    final cols = ((imageRect.width + rotatedWidth * 2) / horizontalSpacing)
        .ceil() + 1;
    final rows = ((imageRect.height + rotatedHeight * 2) / verticalSpacing)
        .ceil() + 1;

    // ===== 4. 计算起始位置，保证整体居中 =====
    final totalWidth = (cols - 1) * horizontalSpacing;
    final totalHeight = (rows - 1) * verticalSpacing;
    final startX = imageRect.left + (imageRect.width - totalWidth) / 2;
    final startY = imageRect.top + (imageRect.height - totalHeight) / 2;

    // ===== 5. 遍历绘制 =====
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        double x = startX + col * horizontalSpacing;
        double y = startY + row * verticalSpacing;

        // 智能交错：与导出函数保持一致
        final enableStagger = horizontalSpacing > minHorizontalSpacing * 1.2;
        if (enableStagger && row % 2 == 1) {
          x += horizontalSpacing * 0.5;
        }

        // 过滤掉完全在图片区域外的水印
        if (x >= imageRect.left - rotatedWidth / 2 &&
            x <= imageRect.right - rotatedWidth / 2 &&
            y >= imageRect.top - rotatedHeight / 2 &&
            y <= imageRect.bottom - rotatedHeight / 2) {
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


  void _drawTileWatermark1(Canvas canvas, TextPainter textPainter,
      Rect imageRect) {
    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    final rotationRad = rotation * pi / 180;

    // 计算旋转后文本的边界框
    final cosVal = cos(rotationRad).abs();
    final sinVal = sin(rotationRad).abs();
    final rotatedWidth = textWidth * cosVal + textHeight * sinVal;
    final rotatedHeight = textWidth * sinVal + textHeight * cosVal;

    // 智能间距计算 - 根据文字长度和旋转角度动态调整
    final baseVerticalSpacing = spacing; // 垂直间距由用户控制

    // 根据文字宽度动态调整水平间距，确保不重叠
    final minHorizontalSpacing = rotatedWidth + 20; // 最小间距 = 旋转后宽度 + 20px缓冲
    final userHorizontalSpacing = spacing * 1.8; // 用户期望的间距
    final horizontalSpacing = (minHorizontalSpacing > userHorizontalSpacing)
        ? minHorizontalSpacing
        : userHorizontalSpacing;

    // 根据文字高度动态调整垂直间距，确保不重叠
    final minVerticalSpacing = rotatedHeight + 15; // 最小间距 = 旋转后高度 + 15px缓冲
    final verticalSpacing = (minVerticalSpacing > baseVerticalSpacing)
        ? minVerticalSpacing
        : baseVerticalSpacing;

    // 计算网格数量，确保完全覆盖
    final cols = ((imageRect.width + rotatedWidth * 2) / horizontalSpacing)
        .ceil() + 1;
    final rows = ((imageRect.height + rotatedHeight * 2) / verticalSpacing)
        .ceil() + 1;

    // 计算起始位置，确保居中对齐
    final totalWidth = (cols - 1) * horizontalSpacing;
    final totalHeight = (rows - 1) * verticalSpacing;
    final startX = imageRect.left + (imageRect.width - totalWidth) / 2;
    final startY = imageRect.top + (imageRect.height - totalHeight) / 2;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        // 计算精确位置 - 规律网格，无随机偏移
        double x = startX + col * horizontalSpacing;
        double y = startY + row * verticalSpacing;

        // // 奇偶行交错，形成砖墙效果（只有在间距足够时才交错）
        // if (row % 2 == 1 && horizontalSpacing > rotatedWidth * 1.5) {
        //   x += horizontalSpacing * 0.5;
        // }

        // 检查是否在图片区域内（考虑旋转后的尺寸）
        if (x >= imageRect.left - rotatedWidth / 2 &&
            x <= imageRect.right - rotatedWidth / 2 &&
            y >= imageRect.top - rotatedHeight / 2 &&
            y <= imageRect.bottom - rotatedHeight / 2) {

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

  void _drawDiagonalWatermark(Canvas canvas, TextPainter textPainter,
      Rect imageRect) {
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

    final diagonalLength = sqrt(
        expandedWidth * expandedWidth + expandedHeight * expandedHeight);
    final numDiagonals = (diagonalLength / diagonalSpacing).ceil();

    for (int i = 0; i < numDiagonals; i++) {
      // 主对角线
      _drawDiagonalLine(
          canvas, textPainter, imageRect, i * diagonalSpacing, rotationRad,
          true);
      // 反对角线
      _drawDiagonalLine(
          canvas, textPainter, imageRect, i * diagonalSpacing, rotationRad,
          false);
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
        if (_isPositionInImageRect(
            currentX, currentY, textWidth, textHeight, imageRect)) {
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
        if (_isPositionInImageRect(
            currentX, currentY, textWidth, textHeight, imageRect)) {
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

  bool _isPositionInImageRect(double x, double y, double textWidth,
      double textHeight, Rect imageRect) {
    // 检查文本是否与图片区域有交集
    final textRect = Rect.fromLTWH(x, y, textWidth, textHeight);
    return imageRect.overlaps(textRect);
  }

  // 绘制日期隐水印
  void _drawDateWatermark(Canvas canvas, Rect imageRect) {
    // 获取当前日期时间
    final now = DateTime.now();
    final dateText = '${now.year}/${now.month}/${now.day} ${now.hour}:${now.minute}';
    
    // 创建日期水印文本绘制器
    final dateTextPainter = TextPainter(
      text: TextSpan(
        text: dateText,
        style: TextStyle(
          fontSize: 8, // 小字体
          color: Colors.black.withOpacity(0.03), // 非常低的不透明度
          fontWeight: FontWeight.w300,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    dateTextPainter.layout();
    
    // 在图片右下角添加日期水印
    final dateX = imageRect.right - dateTextPainter.width - 10;
    final dateY = imageRect.bottom - dateTextPainter.height - 5;
    
    canvas.save();
    canvas.translate(dateX, dateY);
    dateTextPainter.paint(canvas, Offset.zero);
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
        oldDelegate.imageSize != imageSize ||
        oldDelegate.containerSize != containerSize ||
        oldDelegate.addDateWatermark != addDateWatermark;
  }
}