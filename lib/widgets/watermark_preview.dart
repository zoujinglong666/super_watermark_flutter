import 'dart:io';
import 'package:flutter/material.dart';

class WatermarkPreview extends StatelessWidget {
  final File image;
  final String watermarkText;
  final double fontSize;
  final Color textColor;
  final double opacity;
  final double rotation;

  const WatermarkPreview({
    super.key,
    required this.image,
    required this.watermarkText,
    required this.fontSize,
    required this.textColor,
    required this.opacity,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Stack(
        children: [
          // 原始图片
          Positioned.fill(
            child: Image.file(
              image,
              fit: BoxFit.contain,
            ),
          ),
          
          // 水印文字 - 多个重复以覆盖整个图片
          ...List.generate(20, (index) {
            final row = index ~/ 4;
            final col = index % 4;
            return Positioned(
              left: col * 120.0 - 60,
              top: row * 80.0 + 40,
              child: Transform.rotate(
                angle: rotation * 3.14159 / 180,
                child: Opacity(
                  opacity: opacity,
                  child: Text(
                    watermarkText,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: const Offset(1, 1),
                          blurRadius: 2,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}