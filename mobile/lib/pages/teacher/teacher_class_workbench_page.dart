import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/api_service.dart';

class TeacherClassWorkbenchPage extends StatefulWidget {
  const TeacherClassWorkbenchPage({super.key});

  @override
  State<TeacherClassWorkbenchPage> createState() =>
      _TeacherClassWorkbenchPageState();
}

class _TeacherClassWorkbenchPageState extends State<TeacherClassWorkbenchPage> {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _attendance;
  Map<String, dynamic>? _qr;
  int? _selectedSessionId;
  bool _loading = true;
  bool _submitting = false;

  List<Map<String, dynamic>> get _sites => ((_data?['sites'] as List?) ?? [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .where((item) => item['status'] == 'ACTIVE')
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showError = true, int? preferredSessionId}) async {
    try {
      final data = await ApiService.getMobileClassWorkbench();
      final sessions = await ApiService.getManageClassSessions();
      final sessionIds =
          sessions.map((item) => (item['id'] as num).toInt()).toSet();
      final candidateSessionId = preferredSessionId ?? _selectedSessionId;
      final selectedSessionId =
          candidateSessionId != null && sessionIds.contains(candidateSessionId)
              ? candidateSessionId
              : (sessions.isNotEmpty
                  ? (sessions.first['id'] as num).toInt()
                  : null);
      Map<String, dynamic>? attendance;
      if (selectedSessionId != null) {
        attendance =
            await ApiService.getManageSessionAttendance(selectedSessionId);
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _sessions = sessions;
        _selectedSessionId = selectedSessionId;
        _attendance = attendance;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (showError) _show(_friendlyError(e), Colors.red);
    }
  }

  Future<Map<String, dynamic>?> _pickSite({required String mode}) async {
    if (_sites.isEmpty) {
      _show('暂无启用的课堂打卡点，请先在打卡点管理中新增或启用课堂点', Colors.orange);
      return null;
    }
    if (_sites.length == 1) return _sites.first;
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text('${_modeLabel(mode)}：选择课堂打卡点'),
              subtitle: const Text('停用打卡点不会出现在这里'),
            ),
            for (final site in _sites)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text('${site['name']}'),
                subtitle: Text(
                  '${site['address'] ?? ''}\n半径 ${site['radiusMeters']} 米',
                ),
                isThreeLine: true,
                onTap: () => Navigator.of(context).pop(site),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSession(String mode) async {
    final site = await _pickSite(mode: mode);
    if (site == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      final result = await ApiService.createMobileClassSession(
        mode: mode,
        siteId: (site['id'] as num).toInt(),
        courseName: '移动端${_modeLabel(mode)}',
        durationMinutes: 45,
      );
      final qr =
          result['qr'] is Map ? Map<String, dynamic>.from(result['qr']) : null;
      final sessionId = (result['id'] as num?)?.toInt() ??
          (qr?['sessionId'] as num?)?.toInt();
      if (mounted) {
        setState(() {
          _qr = qr;
        });
      }
      if (!mounted) return;
      _show('${result['message'] ?? '${_modeLabel(mode)}请求已发出'}', Colors.green);
      await _load(showError: false, preferredSessionId: sessionId);
      if (!mounted) return;
      if (qr != null) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (mounted) _showQr(qr);
      }
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _selectSession(int sessionId) async {
    setState(() {
      _selectedSessionId = sessionId;
      _attendance = null;
      _qr = null;
    });
    await _loadAttendance(sessionId);
  }

  Future<void> _loadAttendance(int sessionId) async {
    try {
      final attendance = await ApiService.getManageSessionAttendance(sessionId);
      if (!mounted) return;
      setState(() => _attendance = attendance);
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e), Colors.red);
    }
  }

  Future<void> _refreshQr() async {
    final sessionId = _selectedSessionId;
    if (sessionId == null) {
      _show('请先选择二维码签到场次', Colors.orange);
      return;
    }
    setState(() => _submitting = true);
    try {
      final qr = await ApiService.generateClassQr(
        sessionId: sessionId,
        expiresInSeconds: 60,
      );
      if (!mounted) return;
      setState(() => _qr = qr);
      _showQr(qr);
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _closeSession() async {
    final sessionId = _selectedSessionId;
    if (sessionId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关闭课堂场次'),
        content: const Text('关闭后学生将不能继续提交该场次签到。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ApiService.closeManageClassSession(sessionId);
      setState(() {
        _selectedSessionId = null;
        _qr = null;
      });
      if (!mounted) return;
      _show('课堂场次已关闭', Colors.green);
      await _load(showError: false);
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showQr(Map<String, dynamic> qr) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        title: const Text('动态二维码签到'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: QrImageView(
                    data: '${qr['token']}',
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text('${qr['courseName'] ?? ''}'),
                Text('有效期 ${qr['expiresInSeconds']} 秒'),
                const SizedBox(height: 8),
                SelectableText(
                  '${qr['token']}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _refreshQr,
            child: const Text('刷新二维码'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _show(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  String _modeLabel(String mode) {
    return switch (mode) {
      'MANUAL' => '普通签到',
      'QR' => '二维码签到',
      'LOCATION' => '位置签到',
      'PHOTO' => '拍照签到',
      _ => mode,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课堂签到管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/teacher/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _actionCard(
                    Icons.touch_app_outlined,
                    '普通签到',
                    '向学生端发送签到请求，学生点击确认后完成签到',
                    () => _createSession('MANUAL'),
                  ),
                  _actionCard(
                    Icons.qr_code_2_outlined,
                    '二维码签到',
                    '生成动态二维码，学生扫码后完成本场次签到',
                    () => _createSession('QR'),
                  ),
                  _actionCard(
                    Icons.location_on_outlined,
                    '位置签到',
                    '选择课堂打卡点，学生必须在范围内定位签到',
                    () => _createSession('LOCATION'),
                  ),
                  _actionCard(
                    Icons.photo_camera_outlined,
                    '拍照签到',
                    '学生拍摄实时人脸照片，与已录入人脸比对后签到',
                    () => _createSession('PHOTO'),
                  ),
                  const SizedBox(height: 16),
                  _buildSessionPanel(),
                  const SizedBox(height: 16),
                  Text('启用中的课堂打卡点',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_sites.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('暂无启用的课堂打卡点'),
                        subtitle: Text('请到打卡点管理中新增或启用课堂类型打卡点'),
                      ),
                    )
                  else
                    for (final site in _sites)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text('${site['name']}'),
                          subtitle: Text(
                              '${site['address'] ?? ''}\n半径 ${site['radiusMeters']} 米'),
                          isThreeLine: true,
                        ),
                      ),
                ],
              ),
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: _submitting ? null : onTap,
      ),
    );
  }

  Widget _buildSessionPanel() {
    final attendance = _attendance ?? {};
    final records = ((attendance['records'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('课堂场次与考勤',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('暂无活跃课堂场次'),
              )
            else ...[
              DropdownButtonFormField<int>(
                initialValue: _dropdownSessionId,
                decoration: const InputDecoration(
                  labelText: '选择课堂场次',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final session in _sessions)
                    DropdownMenuItem<int>(
                      value: (session['id'] as num).toInt(),
                      child: Text(
                        '${_modeLabel('${session['signMode'] ?? 'LOCATION'}')} / ${session['courseName']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _selectSession(value);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _submitting ? null : _refreshQr,
                    icon: const Icon(Icons.qr_code_2_outlined),
                    label: const Text('生成动态码'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selectedSessionId == null
                        ? null
                        : () => _loadAttendance(_selectedSessionId!),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('刷新考勤'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _closeSession,
                    icon: const Icon(Icons.lock_clock_outlined),
                    label: const Text('关闭场次'),
                  ),
                ],
              ),
              if (_qr != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showQr(_qr!),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('查看当前二维码'),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _summaryChip('应到', attendance['total'] ?? 0),
                  const SizedBox(width: 8),
                  _summaryChip('已到', attendance['present'] ?? 0),
                  const SizedBox(width: 8),
                  _summaryChip('缺勤', attendance['absent'] ?? 0),
                  const SizedBox(width: 8),
                  _summaryChip('出勤率', '${attendance['rate'] ?? 0}%'),
                ],
              ),
              const SizedBox(height: 12),
              for (final record in records)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${record['name']} ${record['studentId']}'),
                  subtitle: Text(
                    '时间：${record['time'] ?? '-'}'
                    '${(record['failReason'] ?? '').toString().isEmpty ? '' : '  异常：${record['failReason']}'}',
                  ),
                  trailing: Chip(
                    label: Text(record['checked'] == true ? '已签到' : '未签到'),
                    backgroundColor: record['checked'] == true
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, dynamic value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  int? get _dropdownSessionId {
    final selected = _selectedSessionId;
    if (selected == null) return null;
    final exists = _sessions
        .any((session) => (session['id'] as num?)?.toInt() == selected);
    return exists ? selected : null;
  }
}
