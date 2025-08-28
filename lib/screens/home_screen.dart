import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/watermark_history.dart';
import '../widgets/watermark_preview.dart';
import '../screens/custom_camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final List<Map<String, dynamic>> _colorOptions = [
    {'label': '红色', 'value': Colors.red},
    {'label': '黑色', 'value': Colors.black},
    {'label': '蓝色', 'value': Colors.blue},
    {'label': '绿色', 'value': Colors.green},
    {'label': '橙色', 'value': Colors.orange},
    {'label': '紫色', 'value': Colors.purple},
    {'label': '靛蓝', 'value': Colors.indigo},
    {'label': '灰色', 'value': Colors.grey},
  ];
  // 水印设置
  String _watermarkText = '仅供身份验证使用';
  double _fontSize = 12.0;
  Color _textColor = Colors.red;
  double _opacity = 0.7;
  double _rotation = -30.0;
  double _spacing = 50.0; // 水印间距
  bool _isDownloading = false; // 下载状态
  
  // 图片旋转角度
  double _imageRotation = 0.0;
  
  // 图片缓存相关
  ui.Image? _cachedImage;
  bool _isImageLoading = true;
  String? _lastImagePath;
  
  // 预设水印文本
  final List<Map<String, dynamic>> _presetTexts = [
    {'text': '仅供身份验证使用', 'icon': Icons.verified_user, 'color': Colors.red},
    {'text': '仅供办理XX业务使用', 'icon': Icons.business, 'color': Colors.orange},
    {'text': '仅供银行开户使用', 'icon': Icons.account_balance, 'color': Colors.blue},
    {'text': '仅供贷款申请使用', 'icon': Icons.monetization_on, 'color': Colors.green},
    {'text': '机密', 'icon': Icons.security, 'color': Colors.red},
    {'text': '保密', 'icon': Icons.lock, 'color': Colors.purple},
    {'text': '隐私保护', 'icon': Icons.privacy_tip, 'color': Colors.indigo},
    {'text': '复印件无效', 'icon': Icons.content_copy, 'color': Colors.grey},
  ];
  
  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 加载图片到内存
  Future<void> _loadImageToMemory() async {
    if (_selectedImage == null) return;
    
    try {
      _lastImagePath = _selectedImage!.path;
      final image = await _loadImageFromFile(_selectedImage!);
      if (mounted) {
        setState(() {
          _cachedImage = image;
          _isImageLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
      }
    }
  }

  Future<ui.Image> _loadImageFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FFFE), Color(0xFFE8F5E8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _selectedImage == null
                ? // 没有选择图片时，显示居中的选择界面
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: _buildImageSelector(),
                    ),
                  )
                : // 选择图片后，显示正常的滚动布局
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 水印预览区域
                          _buildWatermarkPreview(),
                          const SizedBox(height: 20),
                          // 水印设置区域
                          _buildWatermarkSettings(),
                          const SizedBox(height: 20),
                          // 下载按钮
                          Row(
                            children: [
                              Expanded(
                                flex: 2, // 占据2份空间
                                child: _buildImageSelectorButton(),
                              ),
                              const SizedBox(width: 16), // 两个按钮之间的间距
                              Expanded(
                                flex: 3, // 占据3份空间
                                child: _buildDownloadButton(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSelectorButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () async {
          final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
          if (pickedFile != null) {
            setState(() {
              _selectedImage = File(pickedFile.path);
              _isImageLoading = true;
              _cachedImage = null;
            });
            await _loadImageToMemory();
          }
        }
        ,
        icon: const Icon(Icons.download, color: Colors.white, size: 18),
        label: const Text(
          '选择文件',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '超级水印',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '隐私守护·安全可靠',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSelector() {
    return Container(
      width:double.infinity,
      height: _selectedImage == null ? 300 : 220,
      padding: const EdgeInsets.all(16),// 居中显示时增加高度
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00BCD4).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _selectedImage == null
          ? InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '点击选择图片',
                    style: TextStyle(
                      fontSize: _selectedImage == null ? 24 : 20, // 居中时字体更大
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '支持身份证、证件照等重要文件',
                    style: TextStyle(
                      fontSize: _selectedImage == null ? 16 : 14, // 居中时字体更大
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedImage == null) ...[  // 只在居中显示时显示额外提示
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00BCD4).withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        '为您的重要文件添加安全水印',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00BCD4),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    _selectedImage!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
                // 添加旋转控制按钮
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.rotate_left, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _imageRotation = (_imageRotation - 90) % 360;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.rotate_right, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _imageRotation = (_imageRotation + 90) % 360;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWatermarkPreview() {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00BCD4).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: RepaintBoundary(
            key: _previewKey,
            child: Container(
              color: Colors.transparent,
          child: WatermarkPreview(
            image: _selectedImage!,
            watermarkText: _watermarkText,
            fontSize: _fontSize,
            textColor: _textColor,
            opacity: _opacity,
            rotation: _rotation,
            spacing: _spacing,
            mode: WatermarkMode.tile,
            imageRotation: _imageRotation, // 传递图片旋转角度
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatermarkSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '水印设置',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const Spacer(),
              // 设置按钮
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BCD4).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: _showSettingsBottomSheet,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.settings, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '调整设置',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 当前设置预览卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00BCD4).withOpacity(0.1),
                  const Color(0xFF4CAF50).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF00BCD4).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.preview,
                      color: const Color(0xFF00BCD4),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '当前设置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                // 使用网格布局让设置项排列更规整
                // 使用网格布局让设置项排列更规整
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _buildSettingChip('文本', _watermarkText.length > 8 ? '${_watermarkText.substring(0, 8)}...' : _watermarkText, Icons.text_fields, onTap: _showSettingsBottomSheet),
                    _buildSettingChip('大小', '${_fontSize.round()}px', Icons.format_size, onTap: _showSettingsBottomSheet),
                    _buildSettingChip('透明度', '${(_opacity * 100).round()}%', Icons.opacity, onTap: _showSettingsBottomSheet),
                    _buildSettingChip('角度', '${_rotation.round()}°', Icons.rotate_right, onTap: _showSettingsBottomSheet),
                    _buildSettingChip('间距', '${_spacing.round()}px', Icons.grid_3x3, onTap: _showSettingsBottomSheet),
                    _buildSettingChip('颜色', _getColorName(_textColor), Icons.palette, color: _textColor, onTap: _showSettingsBottomSheet),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingChip(
      String label,
      String value,
      IconData icon, {
        Color? color,
        VoidCallback? onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // ✅ 圆角更像 Chip
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // ✅ 自适应宽度
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: color ?? const Color(0xFF00BCD4),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // ✅ 自适应高度
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: color ?? const Color(0xFF00BCD4),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // 获取颜色名称的辅助方法
  String _getColorName(Color color) {
    final colorOption = _colorOptions.firstWhere(
      (option) => option['value'] == color,
      orElse: () => {'label': '自定义'},
    );
    return colorOption['label'];
  }

  Widget _buildSliderSection(String title, double value, double min, double max, Function(double) onChanged, String displayValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00BCD4),
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: const Color(0xFF4CAF50),
              overlayColor: const Color(0xFF4CAF50).withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: title == '透明度' ? 9 : (title == '旋转角度' ? 36 : 36),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDownloading 
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : [const Color(0xFF00BCD4), const Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (_isDownloading ? Colors.grey : const Color(0xFF00BCD4)).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isDownloading ? null : _downloadImage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: _isDownloading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '处理中...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    '一键下载',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择图片来源',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('普通拍照'),
                subtitle: const Text('使用系统相机拍摄照片'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    setState(() {
                      _selectedImage = File(image.path);
                      _isImageLoading = true;
                      _cachedImage = null;
                    });
                    await _loadImageToMemory();
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.credit_card, color: Colors.white),
                ),
                title: const Text('身份证拍照'),
                subtitle: const Text('使用专业模式拍摄身份证'),
                onTap: () async {
                  Navigator.pop(context);
                  _openCustomCamera(CameraType.idCardFront);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('从相册选择'),
                subtitle: const Text('选择已有的照片'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() {
                      _selectedImage = File(image.path);
                      _isImageLoading = true;
                      _cachedImage = null;
                    });
                    await _loadImageToMemory();
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  
  // 打开自定义相机
  Future<void> _openCustomCamera(CameraType cameraType) async {
    try {
      final File? capturedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomCameraScreen(cameraType: cameraType),
        ),
      );
      
      if (capturedImage != null) {
        setState(() {
          _selectedImage = capturedImage;
          _isImageLoading = true;
          _cachedImage = null;
        });
        await _loadImageToMemory();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('相机启动失败: $e')),
      );
    }
  }


  Future<void> _downloadImage() async {
    if (_isDownloading) return;
    
    setState(() {
      _isDownloading = true;
    });

    try {
      // 直接使用图片处理方式生成水印图片，避免RepaintBoundary的黑边问题
      final Uint8List watermarkedImageBytes = await _generateWatermarkImage();

      // 使用 image_gallery_saver_plus 保存到相册
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final result = await ImageGallerySaverPlus.saveImage(
        watermarkedImageBytes,
        quality:100,
        name: "watermark_$timestamp",
      );

      // 保存到本地文件用于历史记录
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/watermark_$timestamp.png');
      await file.writeAsBytes(watermarkedImageBytes);
      // 保存到历史记录
      await _saveToHistory(file.path);
      // 显示成功消息
      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('图片已保存到相册'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('保存失败，请检查权限设置'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('保存失败: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  // 使用统一的水印绘制方法生成水印图片
  Future<Uint8List> _generateWatermarkImage() async {
    // 读取原始图片
    final imageBytes = await _selectedImage!.readAsBytes();
    final originalImage = await ui.instantiateImageCodec(imageBytes);
    final frame = await originalImage.getNextFrame();
    final image = frame.image;

    // 计算字体缩放比例，确保与预览效果一致
    final previewContainerHeight = 320.0; // 预览容器的固定高度
    final imageAspectRatio = image.width / image.height;
    final containerAspectRatio = MediaQuery.of(context).size.width / previewContainerHeight;
    
    double previewImageHeight;
    if (imageAspectRatio > containerAspectRatio) {
      // 图片更宽，以宽度为准
      previewImageHeight = MediaQuery.of(context).size.width / imageAspectRatio;
    } else {
      // 图片更高，以高度为准
      previewImageHeight = previewContainerHeight;
    }
    
    // 计算缩放比例：原图高度 / 预览显示高度
    final scaleFactor = image.height / previewImageHeight;
    
    // 使用与预览相同的水印绘制逻辑
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // 如果有旋转角度，先应用旋转变换
    if (_imageRotation != 0) {
      // 计算旋转中心点
      final centerX = image.width / 2;
      final centerY = image.height / 2;
      
      // 平移到中心点，旋转，再平移回原位置
      canvas.translate(centerX, centerY);
      canvas.rotate(_imageRotation * pi / 180);
      canvas.translate(-centerX, -centerY);
    }
    
    // 绘制背景图片
    final paint = Paint();
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      paint,
    );
    
    // 使用与预览相同的水印绘制逻辑
    if (_watermarkText.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: _watermarkText,
          style: TextStyle(
            fontSize: _fontSize * scaleFactor,
            color: _textColor.withOpacity(_opacity),
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // 使用与预览相同的平铺水印逻辑
      _drawTileWatermarkForExport(canvas, textPainter, Size(image.width.toDouble(), image.height.toDouble()), _rotation, _spacing * scaleFactor);
    }
    
    final picture = recorder.endRecording();
    final watermarkedImage = await picture.toImage(image.width, image.height);
    picture.dispose();
    
    // 转换为字节数组
    final byteData = await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
  
  // 与预览保持一致的平铺水印绘制方法
  void _drawTileWatermarkForExport(Canvas canvas, TextPainter textPainter, Size imageSize, double rotation, double spacing) {
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
    final cols = ((imageSize.width + rotatedWidth * 2) / horizontalSpacing).ceil() + 1;
    final rows = ((imageSize.height + rotatedHeight * 2) / verticalSpacing).ceil() + 1;

    // 计算起始位置，确保居中对齐
    final totalWidth = (cols - 1) * horizontalSpacing;
    final totalHeight = (rows - 1) * verticalSpacing;
    final startX = (imageSize.width - totalWidth) / 2;
    final startY = (imageSize.height - totalHeight) / 2;

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
            x <= imageSize.width - rotatedWidth/2 &&
            y >= -rotatedHeight/2 && 
            y <= imageSize.height - rotatedHeight/2) {
          
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


  Future<void> _saveToHistory(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    final history = WatermarkHistory(
      imagePath: imagePath,
      watermarkText: _watermarkText,
      timestamp: DateTime.now(),
    );
    
    List<String> historyList = prefs.getStringList('watermark_history') ?? [];
    historyList.insert(0, history.toJson());
    
    // 只保留最近50条记录
    if (historyList.length > 50) {
      historyList = historyList.take(50).toList();
    }
    
    await prefs.setStringList('watermark_history', historyList);
  }

  // 显示设置底部弹窗
  void _showSettingsBottomSheet() {
    final TextEditingController textController = TextEditingController(text: _watermarkText);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // 顶部拖拽条和标题
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '水印设置',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const Spacer(),
                        // 重置按钮
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              _watermarkText = '仅供身份验证使用';
                              _fontSize = 12.0;
                              _textColor = Colors.red;
                              _opacity = 0.7;
                              _rotation = -30.0;
                              _spacing = 50.0;
                              textController.text = _watermarkText;
                            });
                            setState(() {});
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('重置'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF00BCD4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 设置内容区域
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 文本设置分组
                      _buildSettingGroup(
                        '文本设置',
                        Icons.text_fields,
                        [
                          // 预设模板
                          // 预设模板下拉菜单
                          Row(
                            children: [
                              Icon(Icons.text_snippet, size: 18, color: const Color(0xFF00BCD4)),
                              const SizedBox(width: 8),
                              const Text(
                                '快捷选择',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              const Spacer(),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _presetTexts.any((preset) => preset['text'] == _watermarkText) 
                                          ? _watermarkText 
                                          : null,
                                      isDense: true,
                                      isExpanded: true,
                                      hint: Text(
                                        _presetTexts.any((preset) => preset['text'] == _watermarkText)
                                            ? _watermarkText
                                            : '自定义文本',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                                      items: _presetTexts.map((preset) {
                                        return DropdownMenuItem<String>(
                                          value: preset['text'],
                                          child: Row(
                                            children: [
                                              Icon(
                                                preset['icon'],
                                                size: 16,
                                                color: preset['color'],
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  preset['text'],
                                                  style: const TextStyle(fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newText) {
                                        if (newText != null) {
                                          final preset = _presetTexts.firstWhere(
                                            (p) => p['text'] == newText,
                                          );
                                          setModalState(() {
                                            _watermarkText = newText;
                                            _textColor = preset['color'];
                                            textController.text = _watermarkText;
                                          });
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              )
                            ],

                          ),
                          const SizedBox(height: 20),
                          
                          // 自定义文本输入
                          const Text(
                            '自定义文本',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: TextField(
                              controller: textController,
                              decoration: InputDecoration(
                                hintText: '输入自定义水印文本',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    textController.clear();
                                    setModalState(() {
                                      _watermarkText = '仅供身份验证使用';
                                    });
                                    setState(() {});
                                  },
                                ),
                              ),
                              onChanged: (value) {
                                setModalState(() {
                                  _watermarkText = value.isNotEmpty ? value : '仅供身份验证使用';
                                });
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 样式设置分组
                      _buildSettingGroup(
                        '样式设置',
                        Icons.palette,
                        [
                          // 字体大小
                          _buildEnhancedSlider(
                            '字体大小',
                            Icons.format_size,
                            _fontSize,
                            8,
                            48,
                            '${_fontSize.round()}px',
                            (value) {
                              setModalState(() {
                                _fontSize = value;
                              });
                              setState(() {});
                            },
                          ),
                          
                          // 透明度
                          _buildEnhancedSlider(
                            '透明度',
                            Icons.opacity,
                            _opacity,
                            0.1,
                            1.0,
                            '${(_opacity * 100).round()}%',
                            (value) {
                              setModalState(() {
                                _opacity = value;
                              });
                              setState(() {});
                            },
                          ),
                          
                          // 旋转角度
                          _buildEnhancedSlider(
                            '旋转角度',
                            Icons.rotate_right,
                            _rotation,
                            -90,
                            90,
                            '${_rotation.round()}°',
                            (value) {
                              setModalState(() {
                                _rotation = value;
                              });
                              setState(() {});
                            },
                          ),
                          
                          // 水印间距
                          _buildEnhancedSlider(
                            '水印间距',
                            Icons.grid_3x3,
                            _spacing,
                            10,
                            100,
                            '${_spacing.round()}px',
                            (value) {
                              setModalState(() {
                                _spacing = value;
                              });
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.palette, size: 18, color: const Color(0xFF00BCD4)),
                              const SizedBox(width: 8),
                              const Text(
                                '文字颜色',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<Color>(
                                    value: _textColor,
                                    isDense: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    items: _colorOptions.map((colorOption) {
                                      return DropdownMenuItem<Color>(
                                        value: colorOption['value'],
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: colorOption['value'],
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              colorOption['label'],
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (Color? newColor) {
                                      if (newColor != null) {
                                        setModalState(() {
                                          _textColor = newColor;
                                        });
                                        setState(() {});
                                      }
                                    },
                                    selectedItemBuilder: (BuildContext context) {
                                      return _colorOptions.map((colorOption) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: colorOption['value'],
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              colorOption['label'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),


                        ],
                      ),

                    ],
                  ),
                ),
              ),
              
              // 底部按钮
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF00BCD4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            color: Color(0xFF00BCD4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00BCD4).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text(
                            '应用设置',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 设置分组组件
  Widget _buildSettingGroup(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  // 增强版滑块组件
  Widget _buildEnhancedSlider(
    String title,
    IconData icon,
    double value,
    double min,
    double max,
    String displayValue,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF00BCD4)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00BCD4),
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: const Color(0xFF4CAF50),
              overlayColor: const Color(0xFF4CAF50).withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: title == '透明度' ? 9 : (title.contains('角度') ? 36 : 36),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}