import React, { useEffect, useState } from 'react';
import { Card, Table, Tag, Button, Statistic, Row, Col } from 'antd';
import { CheckCircleOutlined, CloseCircleOutlined } from '@ant-design/icons';
import { checkinApi } from '../api/checkin';

const DormPage: React.FC = () => {
  const [data, setData] = useState<any[]>([]);

  useEffect(() => {
    checkinApi.getDormToday(1).then(setData).catch(() => {});
  }, []);

  const checked = data.filter((item) => item.checked).length;
  const failed = data.filter((item) => item.status === 'FAILED').length;

  const columns = [
    { title: '姓名', dataIndex: 'name', width: 80 },
    { title: '学号', dataIndex: 'studentId', width: 120 },
    { title: '宿舍', dataIndex: 'dorm', width: 100 },
    { title: '打卡时间', dataIndex: 'time', width: 100 },
    {
      title: '状态', dataIndex: 'status', width: 100,
      render: (v: string, r: any) => {
        const text = r.checked ? '已打卡' : v === 'FAILED' ? '异常' : '未打卡';
        const color = r.checked ? 'green' : v === 'FAILED' ? 'gold' : 'red';
        const icon = r.checked ? <CheckCircleOutlined /> : <CloseCircleOutlined />;
        return <Tag color={color} icon={icon}>{text}</Tag>;
      },
    },
    {
      title: '操作', key: 'action', width: 120,
      render: () => <a>查看详情</a>,
    },
  ];

  return (
    <div>
      <Row gutter={16} style={{ marginBottom: 16 }}>
        <Col span={6}><Card><Statistic title="应打卡" value={data.length} suffix="人" /></Card></Col>
        <Col span={6}><Card><Statistic title="已打卡" value={checked} valueStyle={{ color: '#3f8600' }} suffix="人" /></Card></Col>
        <Col span={6}><Card><Statistic title="未打卡" value={Math.max(0, data.length - checked)} valueStyle={{ color: '#cf1322' }} suffix="人" /></Card></Col>
        <Col span={6}><Card><Statistic title="异常" value={failed} suffix="人" /></Card></Col>
      </Row>
      <Card title="🏠 今日查寝详情 (软件2101班)" extra={<Button>导出报表</Button>}>
        <Table columns={columns} dataSource={data} pagination={false} />
      </Card>
    </div>
  );
};

export default DormPage;
