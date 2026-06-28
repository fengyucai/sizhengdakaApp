import React, { useEffect, useState } from 'react';
import { Button, Card, Col, DatePicker, Form, Input, InputNumber, QRCode, Row, Select, Space, Statistic, Table, Tag, Typography, message } from 'antd';
import dayjs from 'dayjs';
import { checkinApi } from '../api/checkin';

const { Text } = Typography;

const ClassPage: React.FC = () => {
  const [form] = Form.useForm();
  const [summary, setSummary] = useState<any>({ total: 0, present: 0, absent: 0, rate: 0, records: [] });
  const [sessions, setSessions] = useState<any[]>([]);
  const [sites, setSites] = useState<any[]>([]);
  const [sessionId, setSessionId] = useState<number>();
  const [qr, setQr] = useState<any>();
  const [remain, setRemain] = useState(0);

  const loadSessions = () => {
    checkinApi.getClassSessions().then((items) => {
      setSessions(items);
      if (!sessionId && items.length > 0) {
        setSessionId(items[0].id);
        loadAttendance(items[0].id);
      }
    }).catch(() => {});
  };

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

  const createSession = async (values: any) => {
    const [startTime, endTime] = values.classTime;
    const [signStartTime, signEndTime] = values.signTime;
    await checkinApi.createClassSession({
      courseName: values.courseName,
      teacherName: values.teacherName,
      classId: values.classId,
      siteId: values.siteId,
      startTime: startTime.format('YYYY-MM-DDTHH:mm:ss'),
      endTime: endTime.format('YYYY-MM-DDTHH:mm:ss'),
      signStartTime: signStartTime.format('YYYY-MM-DDTHH:mm:ss'),
      signEndTime: signEndTime.format('YYYY-MM-DDTHH:mm:ss'),
    });
    message.success('课堂场次已创建');
    form.resetFields();
    loadSessions();
  };

  useEffect(() => {
    loadSessions();
    checkinApi.getSites('CLASSROOM').then(setSites).catch(() => {});
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
  ];

  return (
    <div>
      <Card title="课堂场次配置" style={{ marginBottom: 16 }}>
        <Form
          form={form}
          layout="inline"
          onFinish={createSession}
          initialValues={{
            classId: 1,
            classTime: [dayjs().hour(8).minute(0), dayjs().hour(9).minute(40)],
            signTime: [dayjs().hour(7).minute(50), dayjs().hour(8).minute(10)],
          }}
        >
          <Form.Item name="courseName" rules={[{ required: true, message: '请输入课程名称' }]}>
            <Input placeholder="课程名称" style={{ width: 160 }} />
          </Form.Item>
          <Form.Item name="teacherName" rules={[{ required: true, message: '请输入教师' }]}>
            <Input placeholder="教师" style={{ width: 120 }} />
          </Form.Item>
          <Form.Item name="classId" rules={[{ required: true, message: '请输入班级ID' }]}>
            <InputNumber placeholder="班级ID" min={1} style={{ width: 110 }} />
          </Form.Item>
          <Form.Item name="siteId" rules={[{ required: true, message: '请选择打卡点' }]}>
            <Select
              placeholder="课堂打卡点"
              style={{ width: 180 }}
              options={sites.map((site) => ({ value: site.id, label: `${site.name} (${site.radiusMeters}m)` }))}
            />
          </Form.Item>
          <Form.Item name="classTime" rules={[{ required: true, message: '请选择上课时间' }]}>
            <DatePicker.RangePicker showTime format="YYYY-MM-DD HH:mm" style={{ width: 330 }} />
          </Form.Item>
          <Form.Item name="signTime" rules={[{ required: true, message: '请选择签到窗口' }]}>
            <DatePicker.RangePicker showTime format="YYYY-MM-DD HH:mm" style={{ width: 330 }} />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit">创建场次</Button>
          </Form.Item>
        </Form>
      </Card>

      <Card style={{ marginBottom: 16 }}>
        <Space>
          <span>课堂场次</span>
          <Select
            style={{ width: 430 }}
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
          <Button onClick={loadSessions}>刷新场次</Button>
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
          <Card title="📚 课堂签到">
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
