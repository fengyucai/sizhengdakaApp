import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/privacy_consent_service.dart';

class PrivacyConsentPage extends StatefulWidget {
  const PrivacyConsentPage({super.key, this.reviewOnly = false});

  final bool reviewOnly;

  @override
  State<PrivacyConsentPage> createState() => _PrivacyConsentPageState();
}

class _PrivacyConsentPageState extends State<PrivacyConsentPage> {
  bool _checked = false;
  bool _saving = false;

  Future<void> _accept() async {
    if (!_checked || _saving) return;
    setState(() => _saving = true);
    await PrivacyConsentService.acceptCurrentVersion();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已确认隐私与数据使用说明')),
    );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final canReturn = widget.reviewOnly || context.canPop();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reviewOnly ? '隐私与数据说明' : '首次使用确认'),
        leading: canReturn
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/settings'),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '南华·思政通需要在教学管理场景中使用必要数据',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            '本说明用于让学生和教师在使用前清楚知道数据用途。不同意时可以返回登录页，暂不使用打卡、人脸、定位和管理功能。',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _buildSection(
            icon: Icons.my_location_outlined,
            title: '定位数据',
            text: '用于查寝、课堂位置签到、实习打卡和教师端打卡点维护。定位结果可能包含经纬度、省市区、详细地址、定位精度和时间。',
          ),
          _buildSection(
            icon: Icons.face_retouching_natural_outlined,
            title: '人脸数据',
            text: '用于首次人脸录入、拍照签到核验和防代签。移动端进行实时摄像头动作采集，后端调用已配置的人脸识别服务完成注册和比对。',
          ),
          _buildSection(
            icon: Icons.notifications_active_outlined,
            title: '消息与预警',
            text: '用于接收教师发起的课堂签到、请假审批、实习日志评阅、打卡申诉和异常预警处理结果。',
          ),
          _buildSection(
            icon: Icons.assignment_outlined,
            title: '业务记录',
            text: '用于保存打卡记录、实习日志、请假申请、申诉材料和教师审核意见，供学生本人、辅导员和管理员在授权范围内查看处理。',
          ),
          _buildSection(
            icon: Icons.admin_panel_settings_outlined,
            title: '权限边界',
            text: '学生仅查看和提交本人数据；辅导员/教师仅处理自己负责班级范围内的数据；管理员用于系统维护和全局配置。',
          ),
          if (!widget.reviewOnly) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _checked,
              onChanged: (value) => setState(() => _checked = value ?? false),
              title: const Text('我已阅读并同意上述隐私与数据使用说明'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _checked && !_saving ? _accept : null,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('同意并继续'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      await context.read<AuthService>().logout();
                      if (!context.mounted) return;
                      context.go('/login');
                    },
              child: const Text('暂不同意并退出登录'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(text, style: const TextStyle(color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
