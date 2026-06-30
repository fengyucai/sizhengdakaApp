import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI思政打卡',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('面向计算机学院学生管理与思政教育场景，覆盖查寝、上课、实习、请假、消息、申诉和统计闭环。'),
                ],
              ),
            ),
          ),
          _InfoTile(
            icon: Icons.fact_check_outlined,
            title: '管理闭环',
            content: '学生端提交打卡、日志、请假和申诉；辅导员/教师端进行审批、评阅和异常处理。',
          ),
          _InfoTile(
            icon: Icons.face_retouching_natural,
            title: '人脸识别',
            content:
                '当前使用端侧动作采集校验正脸、左转、右转等姿态，再提交百度在线活体检测和人脸库比对。腾讯云、阿里云、百度核身、旷视等金融级动作活体通常需要企业资质或单独开通。',
          ),
          _InfoTile(
            icon: Icons.location_on_outlined,
            title: '定位签到',
            content: '支持手机定位服务、最近定位快速读取和打卡点电子围栏校验。',
          ),
          _InfoTile(
            icon: Icons.school_outlined,
            title: '项目定位',
            content: '项目采用“辅导员出题、学生开发、学院应用、全校推广”的实战育人模式。',
          ),
          _InfoTile(
            icon: Icons.privacy_tip_outlined,
            title: '数据说明',
            content: '考勤、人脸、定位和日志数据仅用于学生管理、实习安全和思政育人场景。',
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(content),
      ),
    );
  }
}
