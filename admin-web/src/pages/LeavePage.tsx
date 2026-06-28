import React, { useEffect, useState } from 'react';
import { Card, Table, Button, Badge, Space, message } from 'antd';
import { checkinApi } from '../api/checkin';

const LeavePage: React.FC = () => {
  const [data, setData] = useState<any[]>([]);

  const load = () => checkinApi.getLeaves().then(setData).catch(() => {});

  useEffect(() => {
    load();
  }, []);

  const review = async (id: number, approved: boolean) => {
    if (approved) await checkinApi.approveLeave(id, '同意');
    else await checkinApi.rejectLeave(id, '不同意');
    message.success('审批已提交');
    load();
  };

  const columns = [
    { title: '申请人', dataIndex: 'name' },
    { title: '类型', dataIndex: 'type' },
    { title: '起止时间', render: (_: any, r: any) => `${r.start} ~ ${r.end}` },
    { title: '原因', dataIndex: 'reason' },
    {
      title: '状态', dataIndex: 'status',
      render: (v: string) => {
        const map: Record<string, { color: string; text: string }> = {
          PENDING: { color: 'processing', text: '待审批' },
          APPROVED: { color: 'success', text: '已批准' },
          REJECTED: { color: 'error', text: '已驳回' },
        };
        const s = map[v] || { color: 'default', text: v };
        return <Badge status={s.color as any} text={s.text} />;
      },
    },
    {
      title: '操作', key: 'action',
      render: (_: any, r: any) => r.status === 'PENDING' ? (
        <Space>
          <Button type="link" size="small" onClick={() => review(r.id, true)}>批准</Button>
          <Button type="link" danger size="small" onClick={() => review(r.id, false)}>驳回</Button>
        </Space>
      ) : <span>—</span>,
    },
  ];

  return (
    <Card title="📋 请假审批" extra={<Badge count={data.filter((item) => item.status === 'PENDING').length}><Button>待审批</Button></Badge>}>
      <Table columns={columns} dataSource={data} pagination={false} />
    </Card>
  );
};

export default LeavePage;
