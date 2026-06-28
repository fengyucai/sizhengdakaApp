import React, { useEffect, useState } from 'react';
import { Button, Card, Form, Input, InputNumber, message, Select, Table, Tag } from 'antd';
import { checkinApi } from '../api/checkin';

const SitesPage: React.FC = () => {
  const [form] = Form.useForm();
  const [data, setData] = useState<any[]>([]);

  const load = () => checkinApi.getSites().then(setData).catch(() => {});

  useEffect(() => {
    load();
  }, []);

  const create = async (values: any) => {
    await checkinApi.createSite(values);
    message.success('打卡点已创建');
    form.resetFields();
    load();
  };

  const disable = async (id: number) => {
    await checkinApi.disableSite(id);
    message.success('打卡点已停用');
    load();
  };

  const columns = [
    { title: '名称', dataIndex: 'name' },
    {
      title: '类型',
      dataIndex: 'type',
      width: 120,
      render: (v: string) => <Tag color={typeColor(v)}>{typeLabel(v)}</Tag>,
    },
    { title: '纬度', dataIndex: 'latitude', width: 120 },
    { title: '经度', dataIndex: 'longitude', width: 120 },
    { title: '半径(米)', dataIndex: 'radiusMeters', width: 100 },
    { title: '地址', dataIndex: 'address' },
    {
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (v: string) => <Tag color={v === 'ACTIVE' ? 'green' : 'default'}>{v === 'ACTIVE' ? '启用' : '停用'}</Tag>,
    },
    {
      title: '操作',
      width: 100,
      render: (_: any, record: any) => record.status === 'ACTIVE'
        ? <Button type="link" danger onClick={() => disable(record.id)}>停用</Button>
        : <span>—</span>,
    },
  ];

  return (
    <div>
      <Card title="新增打卡点" style={{ marginBottom: 16 }}>
        <Form form={form} layout="inline" onFinish={create} initialValues={{ type: 'DORM', radiusMeters: 300 }}>
          <Form.Item name="name" rules={[{ required: true, message: '请输入名称' }]}>
            <Input placeholder="名称" style={{ width: 160 }} />
          </Form.Item>
          <Form.Item name="type" rules={[{ required: true }]}>
            <Select
              style={{ width: 130 }}
              options={[
                { value: 'DORM', label: '宿舍' },
                { value: 'CLASSROOM', label: '教室' },
                { value: 'INTERNSHIP', label: '实习单位' },
              ]}
            />
          </Form.Item>
          <Form.Item name="latitude" rules={[{ required: true, message: '请输入纬度' }]}>
            <InputNumber placeholder="纬度" precision={7} style={{ width: 130 }} />
          </Form.Item>
          <Form.Item name="longitude" rules={[{ required: true, message: '请输入经度' }]}>
            <InputNumber placeholder="经度" precision={7} style={{ width: 130 }} />
          </Form.Item>
          <Form.Item name="radiusMeters" rules={[{ required: true, message: '请输入半径' }]}>
            <InputNumber min={20} max={5000} placeholder="半径" style={{ width: 100 }} />
          </Form.Item>
          <Form.Item name="address">
            <Input placeholder="详细地址" style={{ width: 220 }} />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit">创建</Button>
          </Form.Item>
        </Form>
      </Card>
      <Card title="打卡点列表">
        <Table rowKey="id" columns={columns} dataSource={data} pagination={{ pageSize: 10 }} />
      </Card>
    </div>
  );
};

function typeLabel(type: string) {
  if (type === 'DORM') return '宿舍';
  if (type === 'CLASSROOM') return '教室';
  if (type === 'INTERNSHIP') return '实习单位';
  return type;
}

function typeColor(type: string) {
  if (type === 'DORM') return 'blue';
  if (type === 'CLASSROOM') return 'green';
  if (type === 'INTERNSHIP') return 'purple';
  return 'default';
}

export default SitesPage;
