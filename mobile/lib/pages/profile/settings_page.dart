import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/native_capability_config.dart';
import '../../services/privacy_consent_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _fastLocation = true;
  bool _loaded = false;
  String _privacyAcceptedAt = '尚未确认';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fastLocation = prefs.getBool('fastLocationEnabled') ?? true;
      _privacyAcceptedAt = '读取中...';
      _loaded = true;
    });
    final acceptedAt = await PrivacyConsentService.acceptedAtText();
    if (!mounted) return;
    setState(() => _privacyAcceptedAt = acceptedAt);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    value: _fastLocation,
                    title: const Text('快速定位'),
                    subtitle: const Text(
                      '优先使用手机定位服务和高德原生定位，缩短课堂、查寝和实习打卡等待时间。',
                    ),
                    secondary: const Icon(Icons.my_location_outlined),
                    onChanged: (value) {
                      setState(() => _fastLocation = value);
                      _saveBool('fastLocationEnabled', value);
                    },
                  ),
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.task_alt_outlined),
                    title: Text('提交结果反馈'),
                    subtitle: Text('打卡、请假、日志和申诉提交后显示明确反馈，并刷新对应记录。'),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('隐私与数据使用说明'),
                    subtitle: Text('确认时间：$_privacyAcceptedAt'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/privacy/review'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.gps_fixed_outlined),
                    title: const Text('定位能力'),
                    subtitle: Text(
                      '${NativeCapabilityConfig.locationEngineLabel}\n'
                      '当前优先使用高德 Android 定位 SDK，失败时回退到系统融合定位。',
                    ),
                    isThreeLine: true,
                  ),
                ),
                _buildFaceCapabilityCard(),
              ],
            ),
    );
  }

  Widget _buildFaceCapabilityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '人脸识别能力',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${NativeCapabilityConfig.faceEngineLabel}\n'
              '登录后的人脸注册和拍照签到均使用实时摄像头动作采集，后端通过腾讯云人脸库完成注册、搜索和比对。',
            ),
            const SizedBox(height: 12),
            _buildStatusLine('采集方式', '实时摄像头动作采集'),
            _buildStatusLine('服务端比对', '腾讯云人脸识别'),
            _buildStatusLine('适用场景', '人脸注册、拍照签到、人脸核验'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
