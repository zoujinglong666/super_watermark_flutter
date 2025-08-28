import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../main.dart' show cameras; // 导入全局相机列表

class CustomCameraScreen extends StatefulWidget {
  final CameraType cameraType;
  
  const CustomCameraScreen({
    Key? key, 
    this.cameraType = CameraType.normal
  }) : super(key: key);

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

enum CameraType {
  normal,
  idCardFront,
  idCardBack,
  businessLicense,
  bankCard,
  portrait
}

class _CustomCameraScreenState extends State<CustomCameraScreen> with WidgetsBindingObserver {
  late CameraController _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isRearCameraSelected = true;
  bool _isFlashOn = false;
  bool _isTakingPicture = false;
  
  // 相机覆盖层配置
  double _opacity = 0.5;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 立即初始化相机，确保控制器单例
    _initCamera();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 确保在 dispose 时才释放控制器
    if (_isCameraInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 只有在相机已初始化时才处理生命周期
    if (!_isCameraInitialized) return;
    
    if (state == AppLifecycleState.inactive) {
      // 应用进入后台时暂停相机
      _controller.dispose();
      setState(() {
        _isCameraInitialized = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      // 应用回到前台时重新初始化相机
      _initCamera();
    }
  }
  
  Future<bool> _checkAndRequestPermissions() async {
    // 检查相机权限
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('相机权限被拒绝，请在设置中手动授予权限'))
          );
        }
        return false;
      }
    }
    
    // 检查存储权限
    var storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('存储权限被拒绝，请在设置中手动授予权限'))
          );
        }
        return false;
      }
    }
    
    return true;
  }

  Future<void> _initCamera() async {
    try {
      // 检查并请求权限
      final hasPermission = await _checkAndRequestPermissions();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要相机权限才能使用此功能'))
          );
        }
        return;
      }
      
      // 使用全局相机列表或重新获取
      if (cameras.isNotEmpty) {
        _cameras = cameras;
      } else {
        _cameras = await availableCameras();
      }
      
      if (_cameras.isEmpty) {
        print('没有找到可用的相机');
        return;
      }
      
      // 选择合适的相机
      CameraDescription selectedCamera;
      if (_isRearCameraSelected) {
        selectedCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );
      } else {
        selectedCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );
      }
      
      print('选择的相机: ${selectedCamera.name}, 方向: ${selectedCamera.lensDirection}');
      
      // 创建相机控制器（只创建一次）
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      // 添加相机状态监听器
      _controller.addListener(() {
        if (mounted) {
          if (_controller.value.hasError) {
            print('相机错误: ${_controller.value.errorDescription}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('相机错误: ${_controller.value.errorDescription}'))
            );
          }
        }
      });
      
      // 初始化相机
      await _controller.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        
        print('相机初始化成功');
        print('相机预览尺寸: ${_controller.value.previewSize}');
        print('相机传感器方向: ${_controller.description.sensorOrientation}');
        print('相机宽高比: ${_controller.value.aspectRatio}');
      }
    } catch (e) {
      print('相机初始化失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相机初始化失败: $e'))
        );
      }
    }
  }
  
  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _isTakingPicture) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('相机未准备好，请稍后再试'))
        );
      }
      return;
    }
    
    try {
      setState(() {
        _isTakingPicture = true;
      });
      
      // 拍照前闪烁动画
      await _flashAnimation();
      final XFile photo = await _controller.takePicture();
      // 保存到临时目录
      final directory = await getTemporaryDirectory();
      final String fileName = path.basename(photo.path);
      final String filePath = '${directory.path}/$fileName';
      
      final File savedImage = File(photo.path);
      await savedImage.copy(filePath);
      
      if (!mounted) return;
      
      // 返回拍照结果
      Navigator.pop(context, savedImage);
    } catch (e) {
      print('拍照错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }
  
  Future<void> _flashAnimation() async {
    setState(() {
      _opacity = 1.0;
    });
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      setState(() {
        _opacity = 0.0;
      });
    }
    
    await Future.delayed(const Duration(milliseconds: 100));
  }
  
  void _toggleCamera() async {
    if (_cameras.length < 2) return;
    
    setState(() {
      _isCameraInitialized = false;
      _isRearCameraSelected = !_isRearCameraSelected;
    });
    
    await _controller.dispose();
    await _initCamera();
  }
  
  void _toggleFlash() async {
    if (!_isCameraInitialized) return;
    
    try {
      if (_isFlashOn) {
        await _controller.setFlashMode(FlashMode.off);
      } else {
        await _controller.setFlashMode(FlashMode.torch);
      }
      
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('闪光灯控制失败: $e'))
      );
    }
  }
  
  // 处理点击对焦
  void _onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (!_isCameraInitialized) {
      return;
    }

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    
    try {
      _controller.setExposurePoint(offset);
      _controller.setFocusPoint(offset);
      
      // 显示对焦动画
      setState(() {
        // 这里可以添加对焦动画效果
      });
    } catch (e) {
      print('设置对焦点失败: $e');
    }
  }

  // 使用 AspectRatio 包裹预览，避免因为尺寸不合适被系统销毁
  Widget _cameraPreviewWidget() {
    if (!_isCameraInitialized) {
      return const Center(
        child: Text(
          '相机未初始化',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    
    // 使用 AspectRatio 包裹预览，避免因为尺寸不合适被系统销毁
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: CameraPreview(
        _controller,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _onViewFinderTap(details, constraints),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 添加调试信息
    print('相机状态: 初始化=${_isCameraInitialized}');
    if (_isCameraInitialized) {
      print('相机预览尺寸: ${_controller.value.previewSize}');
      print('相机传感器方向: ${_controller.description.sensorOrientation}');
      print('相机宽高比: ${_controller.value.aspectRatio}');
    }
    
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              const Text(
                '相机初始化中...',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              // 显示初始化状态
              Text(
                '初始化状态: ${_isCameraInitialized ? '完成' : '未完成'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // 重新初始化相机
                  _initCamera();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text('重试', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 相机预览 - 使用 AspectRatio 包裹
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Center(
                child: _cameraPreviewWidget(),
              ),
            ),
          ),
          
          // 闪光动画层
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 100),
              child: Container(
                color: Colors.white,
              ),
            ),
          ),
          
          // 相机覆盖引导层
          Positioned.fill(
            child: _buildCameraOverlay(widget.cameraType),
          ),
          
          // 顶部操作栏
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 返回按钮
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  
                  // 右侧功能按钮组
                  Row(
                    children: [
                      // 闪光灯按钮
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                          ),
                          onPressed: _toggleFlash,
                        ),
                      ),
                      
                      // 切换相机按钮
                      if (_cameras.length > 1)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                            onPressed: _toggleCamera,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // 底部操作区
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // 提示文本
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    _getCameraTypeText(widget.cameraType),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // 拍照按钮
                Center(
                  child: GestureDetector(
                    onTap: _isTakingPicture ? null : _takePicture,
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        color: _isTakingPicture ? Colors.grey : Colors.transparent,
                      ),
                      child: Center(
                        child: Container(
                          height: 60,
                          width: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
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
    );
  }
  
  String _getCameraTypeText(CameraType type) {
    switch (type) {
      case CameraType.idCardFront:
        return '请将身份证人像面放入框内，并保持光线充足';
      case CameraType.idCardBack:
        return '请将身份证国徽面放入框内，并保持光线充足';
      case CameraType.businessLicense:
        return '请将营业执照放入框内，并保持光线充足';
      case CameraType.bankCard:
        return '请将银行卡放入框内，并保持光线充足';
      case CameraType.portrait:
        return '请将脸部放入框内，保持正面面对相机';
      case CameraType.normal:
      default:
        return '请对准拍摄物体，点击按钮拍照';
    }
  }
  
  Widget _buildCameraOverlay(CameraType type) {
    switch (type) {
      case CameraType.idCardFront:
        return _buildIdCardFrontOverlay();
      case CameraType.idCardBack:
        return _buildIdCardBackOverlay();
      case CameraType.businessLicense:
        return _buildBusinessLicenseOverlay();
      case CameraType.bankCard:
        return _buildBankCardOverlay();
      case CameraType.portrait:
        return _buildPortraitOverlay();
      case CameraType.normal:
      default:
        return Container(); // 普通模式不需要覆盖层
    }
  }
  
  Widget _buildIdCardFrontOverlay() {
    return CustomPaint(
      painter: OverlayPainter(
        overlayType: OverlayType.idCardFront,
        borderColor: Colors.white,
        overlayColor: Colors.black.withOpacity(0.5),
      ),
    );
  }
  
  Widget _buildIdCardBackOverlay() {
    return CustomPaint(
      painter: OverlayPainter(
        overlayType: OverlayType.idCardBack,
        borderColor: Colors.white,
        overlayColor: Colors.black.withOpacity(0.5),
      ),
    );
  }
  
  Widget _buildBusinessLicenseOverlay() {
    return CustomPaint(
      painter: OverlayPainter(
        overlayType: OverlayType.businessLicense,
        borderColor: Colors.white,
        overlayColor: Colors.black.withOpacity(0.5),
      ),
    );
  }
  
  Widget _buildBankCardOverlay() {
    return CustomPaint(
      painter: OverlayPainter(
        overlayType: OverlayType.bankCard,
        borderColor: Colors.white,
        overlayColor: Colors.black.withOpacity(0.5),
      ),
    );
  }
  
  Widget _buildPortraitOverlay() {
    return CustomPaint(
      painter: OverlayPainter(
        overlayType: OverlayType.portrait,
        borderColor: Colors.white,
        overlayColor: Colors.black.withOpacity(0.5),
      ),
    );
  }
}

// 覆盖层类型
enum OverlayType {
  idCardFront,
  idCardBack,
  businessLicense,
  bankCard,
  portrait
}

// 自定义绘制覆盖层
class OverlayPainter extends CustomPainter {
  final OverlayType overlayType;
  final Color borderColor;
  final Color overlayColor;
  
  OverlayPainter({
    required this.overlayType,
    required this.borderColor,
    required this.overlayColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;
    
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // 绘制全屏半透明背景
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // 根据不同类型绘制不同的镂空区域
    switch (overlayType) {
      case OverlayType.idCardFront:
        _drawIdCardFront(canvas, size, paint, borderPaint);
        break;
      case OverlayType.idCardBack:
        _drawIdCardBack(canvas, size, paint, borderPaint);
        break;
      case OverlayType.businessLicense:
        _drawBusinessLicense(canvas, size, paint, borderPaint);
        break;
      case OverlayType.bankCard:
        _drawBankCard(canvas, size, paint, borderPaint);
        break;
      case OverlayType.portrait:
        _drawPortrait(canvas, size, paint, borderPaint);
        break;
    }
  }
  
  void _drawIdCardFront(Canvas canvas, Size size, Paint paint, Paint borderPaint) {
    // 身份证比例约为 85.6mm x 54mm，宽高比约为 1.585
    final double cardWidth = size.width * 0.85;
    final double cardHeight = cardWidth / 1.585;
    
    final double left = (size.width - cardWidth) / 2;
    final double top = (size.height - cardHeight) / 2;
    
    final Rect cardRect = Rect.fromLTWH(left, top, cardWidth, cardHeight);
    
    // 绘制镂空区域
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cardRect);
    
    canvas.drawPath(path, paint..blendMode = BlendMode.clear);
    canvas.drawPath(path, paint..blendMode = BlendMode.srcOver);
    
    // 绘制身份证边框
    canvas.drawRect(cardRect, borderPaint);
  }
  
  void _drawIdCardBack(Canvas canvas, Size size, Paint paint, Paint borderPaint) {
    // 身份证比例约为 85.6mm x 54mm，宽高比约为 1.585
    final double cardWidth = size.width * 0.85;
    final double cardHeight = cardWidth / 1.585;
    
    final double left = (size.width - cardWidth) / 2;
    final double top = (size.height - cardHeight) / 2;
    
    final Rect cardRect = Rect.fromLTWH(left, top, cardWidth, cardHeight);
    
    // 绘制镂空区域
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cardRect);
    
    canvas.drawPath(path, paint..blendMode = BlendMode.clear);
    canvas.drawPath(path, paint..blendMode = BlendMode.srcOver);
    
    // 绘制身份证边框
    canvas.drawRect(cardRect, borderPaint);
  }
  
  void _drawBusinessLicense(Canvas canvas, Size size, Paint paint, Paint borderPaint) {
    // 营业执照比例约为 A4，宽高比约为 1/1.414
    final double licenseWidth = size.width * 0.85;
    final double licenseHeight = licenseWidth * 1.414;
    
    final double left = (size.width - licenseWidth) / 2;
    final double top = (size.height - licenseHeight) / 2;
    
    final Rect licenseRect = Rect.fromLTWH(left, top, licenseWidth, licenseHeight);
    
    // 绘制镂空区域
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(licenseRect);
    
    canvas.drawPath(path, paint..blendMode = BlendMode.clear);
    canvas.drawPath(path, paint..blendMode = BlendMode.srcOver);
    
    // 绘制营业执照边框
    canvas.drawRect(licenseRect, borderPaint);
  }
  
  void _drawBankCard(Canvas canvas, Size size, Paint paint, Paint borderPaint) {
    // 银行卡比例约为 85.6mm x 54mm，宽高比约为 1.585
    final double cardWidth = size.width * 0.85;
    final double cardHeight = cardWidth / 1.585;
    
    final double left = (size.width - cardWidth) / 2;
    final double top = (size.height - cardHeight) / 2;
    
    final Rect cardRect = Rect.fromLTWH(left, top, cardWidth, cardHeight);
    
    // 绘制镂空区域
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cardRect);
    
    canvas.drawPath(path, paint..blendMode = BlendMode.clear);
    canvas.drawPath(path, paint..blendMode = BlendMode.srcOver);
    
    // 绘制银行卡边框
    canvas.drawRect(cardRect, borderPaint);
  }
  
  void _drawPortrait(Canvas canvas, Size size, Paint paint, Paint borderPaint) {
    // 人脸识别框，圆形
    final double diameter = size.width * 0.7;
    final double left = (size.width - diameter) / 2;
    final double top = (size.height - diameter) / 2 - 50; // 稍微上移一点
    
    final Rect faceRect = Rect.fromLTWH(left, top, diameter, diameter);
    
    // 绘制镂空区域
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(faceRect);
    
    canvas.drawPath(path, paint..blendMode = BlendMode.clear);
    canvas.drawPath(path, paint..blendMode = BlendMode.srcOver);
    
    // 绘制人脸边框
    canvas.drawOval(faceRect, borderPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}