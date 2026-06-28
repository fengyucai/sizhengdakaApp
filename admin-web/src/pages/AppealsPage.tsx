import React, { useEffect, useState } from 'react';
import { Button, Card, Input, message, Space, Table, Tag } from 'antd';
import { checkinApi } from '../api/checkin';

const AppealsPage: React.FC = () => {
  const [data, setData] = useState<any[]>([]);
  const [comments, setComments] = useState<Record<number, string>>({});

  const load = () => checkinApi.getAppeals().then(setData).catch(() => {});

  useEffect(() => {
    load();
  }, []);

  const review = async (id: number, approved: boolean) => {
    await checkinApi.reviewAppeal(id, approved, comments[id] || '');
    message.success(approved ? '申诉已通过' : '申诉已驳回');
    load();
  };

  const columns = [
    { title: '学生', dataIndex: 'name', width: 100 },
    { title: '学号', dataIndex: 'studentId', width: 120 },
    { title: '类型', dataIndex: 'type', width: 90 },
    { title: '打卡时间', dataIndex: 'time', width: 150 },
    { title: '失败原因', dataIndex: 'failReason' },
    { title: '申诉原因', dataIndex: 'appealReason' },
    {
      title: '状态',
      dataIndex: 'appealStatus',
      width: 100,
      render: () => <Tag color="processing">待审核</Tag>,
    },
    {
      title: '审核意见',
      width: 220,
      render: (_: any, record: any) => (
        <Input
          placeholder="填写审核意见"
          value={comments[record.id] || ''}
          onChange={(e) => setComments((prev) => ({ ...prev, [record.id]: e.target.value }))}
        />
      ),
    },
    {
      title: '操作',
      width: 150,
      render: (_: any, record: any) => (
        <Space>
          <Button type="link" onClick={() => review(record.id, true)}>通过</Button>
          <Button type="link" danger onClick={() => review(record.id, false)}>驳回</Button>
        </Space>
      ),
    },
  ];

  return (
    <Card title="异常申诉审核">
      <Table rowKey="id" columns={columns} dataSource={data} pagination={{ pageSize: 10 }} />
    </Card>
  );
};

export default AppealsPage;
