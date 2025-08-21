import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/watermark_history.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<WatermarkHistory> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = prefs.getStringList('watermark_history') ?? [];
      
      setState(() {
        _history = historyList
            .map((json) => WatermarkHistory.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要清空所有历史记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('watermark_history');
              setState(() {
                _history.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('历史记录已清空')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHistoryItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = prefs.getStringList('watermark_history') ?? [];
    
    if (index < historyList.length) {
      historyList.removeAt(index);
      await prefs.setStringList('watermark_history', historyList);
      
      setState(() {
        _history.removeAt(index);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('记录已删除')),
      );
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
          child: Column(
            children: [
              // 自定义AppBar
              _buildCustomAppBar(),
              
              // 内容区域
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                        ),
                      )
                    : Column(
                        children: [
                          // 统计信息卡片
                          _buildStatsCard(),
                          
                          // 历史记录列表
                          Expanded(
                            child: _history.isEmpty
                                ? _buildEmptyState()
                                : _buildHistoryList(),
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

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.photo_library,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '处理统计',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '已处理 ${_history.length} 张图片',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无历史记录',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '开始添加水印后，这里会显示历史记录',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: File(item.imagePath).existsSync()
                    ? Image.file(
                        File(item.imagePath),
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        Icons.image_not_supported,
                        color: Colors.grey.shade400,
                      ),
              ),
            ),
            title: Text(
              item.watermarkText,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(item.timestamp),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getTimeAgo(item.timestamp),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteHistoryItem(index);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('删除'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.folder_shared,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的记录',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Text(
                    '历史处理记录',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_history.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                onPressed: _clearHistory,
                tooltip: '清空历史记录',
              ),
            ),
        ],
      ),
    );
  }

  // Widget _buildStatsCard() {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  //     padding: const EdgeInsets.all(24),
  //     decoration: BoxDecoration(
  //       gradient: const LinearGradient(
  //         colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
  //         begin: Alignment.topLeft,
  //         end: Alignment.bottomRight,
  //       ),
  //       borderRadius: BorderRadius.circular(20),
  //       boxShadow: [
  //         BoxShadow(
  //           color: const Color(0xFF00BCD4).withOpacity(0.3),
  //           blurRadius: 15,
  //           offset: const Offset(0, 8),
  //         ),
  //       ],
  //     ),
  //     child: Row(
  //       children: [
  //         Container(
  //           padding: const EdgeInsets.all(16),
  //           decoration: BoxDecoration(
  //             color: Colors.white.withOpacity(0.2),
  //             borderRadius: BorderRadius.circular(16),
  //           ),
  //           child: const Icon(
  //             Icons.analytics,
  //             size: 40,
  //             color: Colors.white,
  //           ),
  //         ),
  //         const SizedBox(width: 20),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const Text(
  //                 '处理统计',
  //                 style: TextStyle(
  //                   color: Colors.white,
  //                   fontSize: 20,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //               const SizedBox(height: 8),
  //               Text(
  //                 '已处理 ${_history.length} 张图片',
  //                 style: const TextStyle(
  //                   color: Colors.white70,
  //                   fontSize: 16,
  //                 ),
  //               ),
  //               const SizedBox(height: 4),
  //               Text(
  //                 '保护您的隐私安全',
  //                 style: TextStyle(
  //                   color: Colors.white.withOpacity(0.8),
  //                   fontSize: 12,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  //
  // Widget _buildEmptyState() {
  //   return Center(
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Container(
  //           padding: const EdgeInsets.all(24),
  //           decoration: BoxDecoration(
  //             gradient: LinearGradient(
  //               colors: [
  //                 const Color(0xFF00BCD4).withOpacity(0.1),
  //                 const Color(0xFF4CAF50).withOpacity(0.1),
  //               ],
  //             ),
  //             borderRadius: BorderRadius.circular(50),
  //           ),
  //           child: Icon(
  //             Icons.history,
  //             size: 80,
  //             color: Colors.grey.shade400,
  //           ),
  //         ),
  //         const SizedBox(height: 24),
  //         Text(
  //           '暂无历史记录',
  //           style: TextStyle(
  //             fontSize: 20,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.grey.shade600,
  //           ),
  //         ),
  //         const SizedBox(height: 12),
  //         Text(
  //           '开始添加水印后，这里会显示历史记录',
  //           style: TextStyle(
  //             fontSize: 14,
  //             color: Colors.grey.shade500,
  //           ),
  //           textAlign: TextAlign.center,
  //         ),
  //         const SizedBox(height: 24),
  //         Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  //           decoration: BoxDecoration(
  //             gradient: const LinearGradient(
  //               colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
  //             ),
  //             borderRadius: BorderRadius.circular(25),
  //           ),
  //           child: const Text(
  //             '去添加水印',
  //             style: TextStyle(
  //               color: Colors.white,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  //
  // Widget _buildHistoryList() {
  //   return ListView.builder(
  //     padding: const EdgeInsets.symmetric(horizontal: 20),
  //     itemCount: _history.length,
  //     itemBuilder: (context, index) {
  //       final item = _history[index];
  //       return Container(
  //         margin: const EdgeInsets.only(bottom: 16),
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(16),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withOpacity(0.1),
  //               blurRadius: 10,
  //               offset: const Offset(0, 4),
  //             ),
  //           ],
  //         ),
  //         child: ListTile(
  //           contentPadding: const EdgeInsets.all(20),
  //           leading: Container(
  //             width: 60,
  //             height: 60,
  //             decoration: BoxDecoration(
  //               borderRadius: BorderRadius.circular(12),
  //               gradient: LinearGradient(
  //                 colors: [
  //                   const Color(0xFF00BCD4).withOpacity(0.1),
  //                   const Color(0xFF4CAF50).withOpacity(0.1),
  //                 ],
  //               ),
  //             ),
  //             child: ClipRRect(
  //               borderRadius: BorderRadius.circular(12),
  //               child: File(item.imagePath).existsSync()
  //                   ? Image.file(
  //                       File(item.imagePath),
  //                       fit: BoxFit.cover,
  //                     )
  //                   : Icon(
  //                       Icons.image_not_supported,
  //                       color: Colors.grey.shade400,
  //                       size: 30,
  //                     ),
  //             ),
  //           ),
  //           title: Text(
  //             item.watermarkText,
  //             style: const TextStyle(
  //               fontWeight: FontWeight.w600,
  //               fontSize: 16,
  //               color: Color(0xFF333333),
  //             ),
  //             maxLines: 2,
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //           subtitle: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const SizedBox(height: 8),
  //               Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //                 decoration: BoxDecoration(
  //                   color: const Color(0xFF00BCD4).withOpacity(0.1),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Text(
  //                   _formatDateTime(item.timestamp),
  //                   style: const TextStyle(
  //                     color: Color(0xFF00BCD4),
  //                     fontSize: 12,
  //                     fontWeight: FontWeight.w500,
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(height: 6),
  //               Row(
  //                 children: [
  //                   Icon(
  //                     Icons.access_time,
  //                     size: 14,
  //                     color: Colors.grey.shade500,
  //                   ),
  //                   const SizedBox(width: 4),
  //                   Text(
  //                     _getTimeAgo(item.timestamp),
  //                     style: TextStyle(
  //                       color: Colors.grey.shade500,
  //                       fontSize: 12,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //           trailing: Container(
  //             decoration: BoxDecoration(
  //               color: Colors.red.withOpacity(0.1),
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //             child: PopupMenuButton<String>(
  //               icon: const Icon(Icons.more_vert, color: Colors.red),
  //               onSelected: (value) {
  //                 if (value == 'delete') {
  //                   _deleteHistoryItem(index);
  //                 }
  //               },
  //               itemBuilder: (context) => [
  //                 const PopupMenuItem(
  //                   value: 'delete',
  //                   child: Row(
  //                     children: [
  //                       Icon(Icons.delete, color: Colors.red, size: 20),
  //                       SizedBox(width: 8),
  //                       Text('删除记录'),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }
}
