import 'package:flutter/material.dart';
import '../models/watermark_template.dart';
import '../services/template_service.dart';

class TemplateEditorScreen extends StatefulWidget {
  final WatermarkTemplate? template;
  final VoidCallback? onSaved;

  const TemplateEditorScreen({
    super.key,
    this.template,
    this.onSaved,
  });

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _textController;
  late double _fontSize;
  late Color _textColor;
  late double _opacity;
  late double _rotation;
  late double _spacing;
  late WatermarkPosition _position;

  final List<Color> _colorOptions = [
    Colors.red,
    Colors.black,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.indigo,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    
    _nameController = TextEditingController(text: template?.name ?? '');
    _textController = TextEditingController(text: template?.text ?? '');
    _fontSize = template?.fontSize ?? 12.0;
    _textColor = template?.textColor ?? Colors.red;
    _opacity = template?.opacity ?? 0.7;
    _rotation = template?.rotation ?? -30.0;
    _spacing = template?.spacing ?? 50.0;
    _position = template?.position ?? WatermarkPosition.tile;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入模板名称')),
      );
      return;
    }

    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入水印文本')),
      );
      return;
    }

    final template = WatermarkTemplate(
      id: widget.template?.id ?? TemplateService.generateId(),
      name: _nameController.text.trim(),
      text: _textController.text.trim(),
      fontSize: _fontSize,
      textColor: _textColor,
      opacity: _opacity,
      rotation: _rotation,
      spacing: _spacing,
      position: _position,
      createdAt: widget.template?.createdAt ?? DateTime.now(),
      isDefault: widget.template?.isDefault ?? false,
    );

    final success = await TemplateService.saveTemplate(template);
    if (success) {
      widget.onSaved?.call();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? '新建模板' : '编辑模板'),
        backgroundColor: const Color(0xFF00BCD4),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveTemplate,
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FFFE), Color(0xFFE8F5E8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicSettings(),
              const SizedBox(height: 20),
              _buildStyleSettings(),
              const SizedBox(height: 20),
              _buildPositionSettings(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '基本设置',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '模板名称',
              hintText: '请输入模板名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: '水印文本',
              hintText: '请输入水印文本',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '样式设置',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          _buildSlider('字体大小', _fontSize, 8, 48, '${_fontSize.round()}px', (value) {
            setState(() => _fontSize = value);
          }),
          _buildSlider('透明度', _opacity, 0.1, 1.0, '${(_opacity * 100).round()}%', (value) {
            setState(() => _opacity = value);
          }),
          _buildSlider('旋转角度', _rotation, -90, 90, '${_rotation.round()}°', (value) {
            setState(() => _rotation = value);
          }),
          _buildSlider('间距', _spacing, 20, 100, '${_spacing.round()}px', (value) {
            setState(() => _spacing = value);
          }),
          const SizedBox(height: 16),
          const Text(
            '颜色选择',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _colorOptions.map((color) {
              final isSelected = _textColor == color;
              return GestureDetector(
                onTap: () => setState(() => _textColor = color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF00BCD4) : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '位置设置',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WatermarkPosition.values.map((position) {
              final isSelected = _position == position;
              return GestureDetector(
                onTap: () => setState(() => _position = position),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)],
                          )
                        : null,
                    color: isSelected ? null : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        position.icon,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        position.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String title,
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