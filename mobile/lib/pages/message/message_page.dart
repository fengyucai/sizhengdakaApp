import 'package:flutter/material.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final messages = [
      {'title': '查寝提醒', 'body': '请于23:00前完成查寝打卡', 'time': '21:30', 'read': false},
      {'title': '上课提醒', 'body': '明天上午8:00 数据结构 (A201教室)', 'time': '昨天', 'read': true},
      {'title': '预警通知', 'body': '您已连续2天未完成实习打卡，请尽快打卡', 'time': '06-25', 'read': false},
      {'title': '系统通知', 'body': 'AI思政打卡APP已上线，请及时注册人脸信息', 'time': '06-20', 'read': true},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('消息中心')),
      body: ListView.separated(
        itemCount: messages.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final m = messages[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: m['read'] == true ? Colors.grey.shade200 : Colors.red.shade50,
              child: Icon(
                m['read'] == true ? Icons.notifications_none : Icons.notifications_active,
                color: m['read'] == true ? Colors.grey : Colors.red,
              ),
            ),
            title: Text(m['title'] as String, style: TextStyle(fontWeight: m['read'] == true ? FontWeight.normal : FontWeight.bold)),
            subtitle: Text(m['body'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(m['time'] as String, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          );
        },
      ),
    );
  }
}
