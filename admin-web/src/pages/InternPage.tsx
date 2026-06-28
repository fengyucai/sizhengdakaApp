import React, { useEffect, useState } from 'react';
import { Card, Table, Tag, Statistic, Row, Col, Button, Input, Space, message } from 'antd';
import { checkinApi } from '../api/checkin';

const InternPage: React.FC = () => {
  const [data, setData] = useState<any[]>([]);
  const [logs, setLogs] = useState<any[]>([]);
  const [reviews, setReviews] = useState<Record<number, string>>({});

  const load = () => {
    checkinApi.getInternMonitor().then(setData).catch(() => {});
    checkinApi.getInternLogs().then(setLogs).catch(() => {});
  };

  useEffect(() => {
    load();
  }, []);

  const reviewLog = async (id: number) => {
    const comment = (reviews[id] || '').trim();
    if (comment.length < 2) {
      message.warning('请填写评阅意见');
      return;
    }
    await checkinApi.reviewInternLog(id, comment);
    message.success('评阅已提交');
    setReviews((prev) => ({ ...prev, [id]: '' }));
    load();
  };

  const checked = data.filter((item) => item.checked).length;
  const logged = data.filter((item) => item.log).length;

  const columns = [
    { title: '姓名', dataIndex: 'name', width: 80 },
    { title: '实习单位', dataIndex: 'company' },
    { title: '今日打卡', dataIndex: 'time', width: 80 },
    { title: '今日日志', dataIndex: 'log', ellipsis: true },
    {
      title: '状态', dataIndex: 'status', width: 100,
      render: (v: string) => <Tag color={v === '正常' ? 'green' : 'red'}>{v}</Tag>,
    },
    { title: '操作', render: () => <a>查看日志</a>, width: 80 },
  ];

  const logColumns = [
    { title: '日期', dataIndex: 'workDate', width: 110 },
    { title: '姓名', dataIndex: 'name', width: 90 },
    { title: '学号', dataIndex: 'studentId', width: 120 },
    { title: '实习单位', dataIndex: 'company', width: 180 },
    { title: '日志内容', dataIndex: 'content', ellipsis: true },
    {
      title: '导师评阅',
      dataIndex: 'mentorReview',
      width: 180,
      render: (v: string) => v ? <Tag color="green">{v}</Tag> : <Tag>未评阅</Tag>,
    },
    {
      title: '填写评阅',
      width: 260,
      render: (_: any, record: any) => (
        <Space.Compact style={{ width: '100%' }}>
          <Input
            placeholder="评阅意见"
            value={reviews[record.id] || ''}
            onChange={(e) => setReviews((prev) => ({ ...prev, [record.id]: e.target.value }))}
          />
          <Button type="primary" onClick={() => reviewLog(record.id)}>提交</Button>
        </Space.Compact>
      ),
    },
  ];

  return (
    <div>
      <Row gutter={16} style={{ marginBottom: 16 }}>
        <Col span={6}><Card><Statistic title="实习生总数" value={data.length} suffix="人" /></Card></Col>
        <Col span={6}><Card><Statistic title="今日已打卡" value={checked} valueStyle={{ color: '#3f8600' }} suffix="人" /></Card></Col>
        <Col span={6}><Card><Statistic title="日志提交率" value={data.length ? Math.round((logged * 1000) / data.length) / 10 : 0} suffix="%" /></Card></Col>
        <Col span={6}><Card><Statistic title="异常预警" value={Math.max(0, data.length - checked)} valueStyle={{ color: '#cf1322' }} suffix="人" /></Card></Col>
      </Row>
      <Card title="💼 实习打卡监控" extra={<Button>导出实习档案</Button>}>
        <Table columns={columns} dataSource={data} pagination={false} />
      </Card>
      <Card title="📝 实习日志评阅" style={{ marginTop: 16 }}>
        <Table rowKey="id" columns={logColumns} dataSource={logs} pagination={{ pageSize: 8 }} />
      </Card>
    </div>
  );
};

export default InternPage;
