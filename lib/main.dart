import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 尝试获取可用相机列表
  try {
    cameras = await availableCameras();
    print('可用相机数量: ${cameras.length}');
    for (var camera in cameras) {
      print('相机: ${camera.name}, 方向: ${camera.lensDirection}, 传感器方向: ${camera.sensorOrientation}');
    }
  } on CameraException catch (e) {
    print('相机初始化错误: ${e.code}, ${e.description}');
  }
  
  // 请求相机和存储权限
  await _requestPermissions();
  
  runApp(const WatermarkApp());
}

Future<void> _requestPermissions() async {
  // 请求相机权限
  var cameraStatus = await Permission.camera.status;
  if (!cameraStatus.isGranted) {
    await Permission.camera.request();
  }
  
  // 请求存储权限
  var storageStatus = await Permission.storage.status;
  if (!storageStatus.isGranted) {
    await Permission.storage.request();
  }
  
  // 请求照片权限（iOS特有）
  var photosStatus = await Permission.photos.status;
  if (!photosStatus.isGranted) {
    await Permission.photos.request();
  }
  
  // 请求麦克风权限（如果需要录制视频）
  var microphoneStatus = await Permission.microphone.status;
  if (!microphoneStatus.isGranted) {
    await Permission.microphone.request();
  }
  
  // 检查权限状态
  print('相机权限: ${await Permission.camera.status}');
  print('存储权限: ${await Permission.storage.status}');
  print('照片权限: ${await Permission.photos.status}');
  print('麦克风权限: ${await Permission.microphone.status}');
}

class WatermarkApp extends StatelessWidget {
  const WatermarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '超级水印·隐私守护',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BCD4),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00BCD4),
          elevation: 0,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 8,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00BCD4).withOpacity(0.1),
              const Color(0xFF4CAF50).withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF00BCD4),
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
            ),
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: _currentIndex == 0
                      ? BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: Icon(
                    Icons.water_drop,
                    color: _currentIndex == 0 ? Colors.white : Colors.grey,
                  ),
                ),
                label: '首页',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: _currentIndex == 1
                      ? BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: Icon(
                    Icons.folder_shared,
                    color: _currentIndex == 1 ? Colors.white : Colors.grey,
                  ),
                ),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }
}