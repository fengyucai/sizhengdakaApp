import React, { useEffect, useState } from 'react';
import { Card, Table, Tag, Space, Button, Badge, message } from 'antd';
import { checkinApi } from '../api/checkin';

const AlertsPage: React.FC = () => {
  const [data, setData] = useState<any[]>([]);

  const load = () => checkinApi.getAlerts().then(setData).catch(() => {});

  useEffect(() => {
    load();
  }, []);

  const handle = async (id: number) => {
    await checkinApi.handleAlert(id);
    message.success('已确认处理');
    load();
  };

  const columns = [
    { title: '时间', dataIndex: 'time', width: 100 },
    { title: '标题', dataIndex: 'title', width: 120 },
    { title: '预警内容', dataIndex: 'content' },
    {
      title: '等级', dataIndex: 'level', width: 100,
      render: (v: string) => <Tag color={v === 'RED' ? 'red' : 'gold'}>{v === 'RED' ? '🔴 严重' : '🟡 一般'}</Tag>,
    },
    {
      title: '状态', dataIndex: 'handled', width: 100,
      render: (v: boolean) => v ? <Tag color="default">已处理</Tag> : <Badge status="processing" text="待处理" />,
    },
    {
      title: '操作', key: 'action',
      render: (_: any, r: any) => r.handled ? <span>—</span> : (
        <Space>
          <Button type="link" size="small" onClick={() => handle(r.id)}>确认处理</Button>
          <Button type="link" size="small">联系学生</Button>
        </Space>
      ),
    },
  ];

  return (
    <div>
      <Card style={{ marginBottom: 16 }}>
        <Space size="large">
          <span>🔴 严重预警: <b>{data.filter((item) => item.level === 'RED').length}</b></span>
          <span>🟡 一般预警: <b>{data.filter((item) => item.level !== 'RED').length}</b></span>
          <span>✅ 已处理: <b>{data.filter((item) => item.handled).length}</b></span>
        </Space>
      </Card>
      <Card title="⚠️ 预警列表">
        <Table columns={columns} dataSource={data} pagination={false} />
      </Card>
    </div>
  );
};

export default AlertsPage;
