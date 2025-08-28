import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/watermark_template.dart';

class TemplateService {
  static const String _templatesKey = 'watermark_templates';
  
  // 获取默认模板
  static List<WatermarkTemplate> getDefaultTemplates() {
    return [
      WatermarkTemplate(
        id: 'default_1',
        name: '身份验证',
        text: '仅供身份验证使用',
        fontSize: 12.0,
        textColor: Colors.red,
        opacity: 0.7,
        rotation: -30.0,
        spacing: 50.0,
        position: WatermarkPosition.tile,
        createdAt: DateTime.now(),
        isDefault: true,
      ),
      WatermarkTemplate(
        id: 'default_2',
        name: '银行开户',
        text: '仅供银行开户使用',
        fontSize: 12.0,
        textColor: Colors.blue,
        opacity: 0.7,
        rotation: -30.0,
        spacing: 50.0,
        position: WatermarkPosition.tile,
        createdAt: DateTime.now(),
        isDefault: true,
      ),
      WatermarkTemplate(
        id: 'default_3',
        name: '贷款申请',
        text: '仅供贷款申请使用',
        fontSize: 12.0,
        textColor: Colors.green,
        opacity: 0.7,
        rotation: -30.0,
        spacing: 50.0,
        position: WatermarkPosition.tile,
        createdAt: DateTime.now(),
        isDefault: true,
      ),
      WatermarkTemplate(
        id: 'default_4',
        name: '机密文件',
        text: '机密',
        fontSize: 16.0,
        textColor: Colors.red,
        opacity: 0.8,
        rotation: 45.0,
        spacing: 80.0,
        position: WatermarkPosition.center,
        createdAt: DateTime.now(),
        isDefault: true,
      ),
      WatermarkTemplate(
        id: 'default_5',
        name: '复印无效',
        text: '复印件无效',
        fontSize: 14.0,
        textColor: Colors.grey,
        opacity: 0.6,
        rotation: 0.0,
        spacing: 60.0,
        position: WatermarkPosition.bottomRight,
        createdAt: DateTime.now(),
        isDefault: true,
      ),
    ];
  }

  // 获取所有模板
  static Future<List<WatermarkTemplate>> getAllTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = prefs.getStringList(_templatesKey) ?? [];
    
    List<WatermarkTemplate> customTemplates = templatesJson
        .map((json) => WatermarkTemplate.fromJson(json))
        .toList();
    
    List<WatermarkTemplate> defaultTemplates = getDefaultTemplates();
    
    // 合并默认模板和自定义模板
    return [...defaultTemplates, ...customTemplates];
  }

  // 保存模板
  static Future<bool> saveTemplate(WatermarkTemplate template) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getStringList(_templatesKey) ?? [];
      
      // 检查是否已存在相同ID的模板
      templatesJson.removeWhere((json) {
        final existing = WatermarkTemplate.fromJson(json);
        return existing.id == template.id;
      });
      
      templatesJson.add(template.toJson());
      await prefs.setStringList(_templatesKey, templatesJson);
      return true;
    } catch (e) {
      print('保存模板失败: $e');
      return false;
    }
  }

  // 删除模板
  static Future<bool> deleteTemplate(String templateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getStringList(_templatesKey) ?? [];
      
      templatesJson.removeWhere((json) {
        final template = WatermarkTemplate.fromJson(json);
        return template.id == templateId;
      });
      
      await prefs.setStringList(_templatesKey, templatesJson);
      return true;
    } catch (e) {
      print('删除模板失败: $e');
      return false;
    }
  }

  // 生成唯一ID
  static String generateId() {
    return 'template_${DateTime.now().millisecondsSinceEpoch}';
  }
}