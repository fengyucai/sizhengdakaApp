import React, { useEffect, useState } from 'react';
import { Card, Table, Tag, Statistic, Row, Col, Button } from 'antd';
import { checkinApi } from '../api/checkin';

const InternPage: React.FC = () => {
  const [data, setData] = useState<any[]>([]);

  useEffect(() => {
    checkinApi.getInternMonitor().then(setData).catch(() => {});
  }, []);

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
    </div>
  );
};

export default InternPage;
