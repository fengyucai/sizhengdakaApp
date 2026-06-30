import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _dashboard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load({bool showFeedback = false}) async {
    try {
      final dashboard = await ApiService.getTeacherDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _loading = false;
      });
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('工作台数据已刷新')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理看板加载失败'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _logout() async {
    final auth = context.read<AuthService>();
    await auth.logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('教师工作台'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(showFeedback: true),
          ),
          IconButton(
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_loading) const SizedBox(height: 12),
            Text(
              '${auth.realName ?? '教师'}，请选择要处理的事项',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildEntry(
              icon: Icons.event_available_outlined,
              title: '请假审批',
              subtitle: '审核学生请假申请，审批结果会同步通知学生',
              route: '/teacher/leaves',
            ),
            const SizedBox(height: 12),
            _buildEntry(
              icon: Icons.fact_check_outlined,
              title: '打卡申诉审核',
              subtitle: '处理定位、人脸识别、考勤异常等申诉记录',
              route: '/teacher/appeals',
            ),
            const SizedBox(height: 12),
            _buildEntry(
              icon: Icons.work_history_outlined,
              title: '实习日志评阅',
              subtitle: '查看校外实习日志并填写导师评阅意见',
              route: '/teacher/intern-logs',
            ),
            const SizedBox(height: 12),
            _buildEntry(
              icon: Icons.add_location_alt_outlined,
              title: '打卡点管理',
              subtitle: '维护宿舍、教室、实习单位的坐标、半径和详细地址',
              route: '/teacher/sites',
            ),
            const SizedBox(height: 12),
            _buildEntry(
              icon: Icons.insights_outlined,
              title: '统计报表',
              subtitle: '查看查寝、课堂、实习的周报和趋势数据',
              route: '/teacher/reports',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final dashboard = _dashboard ?? {};
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _buildStat('学生总数', dashboard['studentTotal'], '人',
            Icons.groups_outlined, Colors.blue, '/teacher/students'),
        _buildStat('今日查寝', dashboard['dormChecked'], '人',
            Icons.home_work_outlined, Colors.green, '/teacher/dorm-locations'),
        _buildStat('课堂签到', dashboard['classChecked'], '人',
            Icons.co_present_outlined, Colors.deepPurple, '/teacher/class-workbench'),
        _buildStat('待处理预警', dashboard['pendingAlerts'], '条',
            Icons.warning_amber_outlined, Colors.orange, '/teacher/alerts'),
      ],
    );
  }

  Widget _buildStat(
    String title,
    dynamic value,
    String suffix,
    IconData icon,
    Color color,
    String route,
  ) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    '${(value as num?)?.toInt() ?? 0}$suffix',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntry({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
