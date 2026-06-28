import React, { useEffect, useState } from 'react';
import { Button, Card, Col, QRCode, Row, Select, Space, Statistic, Table, Tag, Typography, message } from 'antd';
import { checkinApi } from '../api/checkin';

const { Text } = Typography;

const ClassPage: React.FC = () => {
  const [summary, setSummary] = useState<any>({ total: 0, present: 0, absent: 0, rate: 0, records: [] });
  const [sessions, setSessions] = useState<any[]>([]);
  const [sessionId, setSessionId] = useState<number>();
  const [qr, setQr] = useState<any>();
  const [remain, setRemain] = useState(0);

  const loadAttendance = (id: number) => {
    checkinApi.getSessionAttendance(id).then(setSummary).catch(() => {});
  };

  const refreshQr = () => {
    if (!sessionId) return;
    checkinApi.generateClassQr(sessionId, 30).then((data) => {
      setQr(data);
      setRemain(data.expiresInSeconds ?? 30);
    }).catch((err) => {
      setQr(undefined);
      setRemain(0);
      message.warning(err?.message || '当前无法生成动态码');
    });
  };

  useEffect(() => {
    checkinApi.getClassSessions(1).then((items) => {
      setSessions(items);
      if (items.length > 0) {
        setSessionId(items[0].id);
        loadAttendance(items[0].id);
      }
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (!qr) return undefined;
    const timer = window.setInterval(() => {
      setRemain((value) => {
        if (value <= 1) {
          refreshQr();
          return 30;
        }
        return value - 1;
      });
    }, 1000);
    return () => window.clearInterval(timer);
  }, [qr, sessionId]);

  useEffect(() => {
    if (sessionId) refreshQr();
  }, [sessionId]);

  const data = summary.records ?? [];

  const columns = [
    { title: '姓名', dataIndex: 'name' },
    { title: '学号', dataIndex: 'studentId' },
    { title: '签到时间', dataIndex: 'time' },
    { title: '失败原因', dataIndex: 'failReason' },
    {
      title: '状态', dataIndex: 'checked',
      render: (v: boolean) => <Tag color={v ? 'green' : 'red'}>{v ? '已签到' : '未签到'}</Tag>,
    },
    { title: '操作', render: () => <a>详情</a> },
  ];

  return (
    <div>
      <Card style={{ marginBottom: 16 }}>
        <Space>
          <span>课堂场次</span>
          <Select
            style={{ width: 360 }}
            value={sessionId}
            options={sessions.map((s) => ({
              value: s.id,
              label: `${s.courseName} / ${s.teacherName} / ${s.signStartTime} - ${s.signEndTime}`,
            }))}
            onChange={(value) => {
              setSessionId(value);
              setQr(undefined);
              loadAttendance(value);
            }}
          />
          <Button onClick={() => sessionId && loadAttendance(sessionId)}>刷新考勤</Button>
        </Space>
      </Card>
      <Row gutter={16} style={{ marginBottom: 16 }}>
        <Col span={6}><Card><Statistic title="应签到" value={summary.total} suffix="人" /></Card></Col>
        <Col span={6}><Card><Statistic title="整体出勤率" value={summary.rate} suffix="%" precision={1} valueStyle={{ color: '#3f8600' }} /></Card></Col>
        <Col span={6}><Card><Statistic title="缺勤人数" value={summary.absent} suffix="人" valueStyle={{ color: '#cf1322' }} /></Card></Col>
        <Col span={6}><Card><Statistic title="已签到" value={summary.present} suffix="人" valueStyle={{ color: '#faad14' }} /></Card></Col>
      </Row>
      <Row gutter={16}>
        <Col span={17}>
          <Card title="📚 今日课堂签到">
            <Table columns={columns} dataSource={data} pagination={false} rowKey="userId" />
          </Card>
        </Col>
        <Col span={7}>
          <Card title="动态签到码" extra={<Button size="small" onClick={refreshQr}>刷新</Button>}>
            <Space direction="vertical" align="center" style={{ width: '100%' }}>
              <QRCode value={qr?.token || 'loading'} size={220} status={qr ? 'active' : 'loading'} />
              <Text strong>{qr?.courseName || summary.courseName || '未选择课堂'}</Text>
              <Text type="secondary">{qr?.siteName || '等待生成动态码'}</Text>
              <Text type={remain <= 10 ? 'danger' : 'secondary'}>{remain} 秒后刷新</Text>
            </Space>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default ClassPage;
