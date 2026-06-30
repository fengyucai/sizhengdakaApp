import React, { useEffect, useState } from 'react';
import { Button, Card, Form, Input, InputNumber, Space, message, Select, Table, Tag } from 'antd';
import { checkinApi } from '../api/checkin';

const SitesPage: React.FC = () => {
  const [form] = Form.useForm();
  const [data, setData] = useState<any[]>([]);
  const [editing, setEditing] = useState<any | null>(null);
  const [resolving, setResolving] = useState(false);

  const load = () => checkinApi.getSites().then(setData).catch(() => {});

  useEffect(() => {
    load();
  }, []);

  const create = async (values: any) => {
    if (editing) {
      await checkinApi.updateSite(editing.id, values);
      message.success('打卡点已更新');
    } else {
      await checkinApi.createSite(values);
      message.success('打卡点已创建');
    }
    setEditing(null);
    form.resetFields();
    load();
  };

  const edit = (record: any) => {
    setEditing(record);
    form.setFieldsValue(record);
  };

  const cancelEdit = () => {
    setEditing(null);
    form.resetFields();
  };

  const geocode = async () => {
    const address = form.getFieldValue('address');
    if (!address) {
      message.warning('请先填写详细地址');
      return;
    }
    setResolving(true);
    try {
      const result = await checkinApi.geocodeAddress(address, '衡阳');
      form.setFieldsValue({
        latitude: result.latitude,
        longitude: result.longitude,
      });
      message.success(`已解析坐标，可信度 ${result.confidence ?? '-'}`);
    } finally {
      setResolving(false);
    }
  };

  const reverseByCoordinates = async () => {
    const latitude = Number(form.getFieldValue('latitude'));
    const longitude = Number(form.getFieldValue('longitude'));
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      message.warning('请先填写有效经纬度');
      return;
    }
    await fillAddressFromCoordinates(latitude, longitude);
  };

  const useCurrentLocation = async () => {
    if (!navigator.geolocation) {
      message.warning('当前浏览器不支持定位，请手动填写坐标后反查地址');
      return;
    }
    setResolving(true);
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const latitude = Number(position.coords.latitude.toFixed(7));
        const longitude = Number(position.coords.longitude.toFixed(7));
        form.setFieldsValue({ latitude, longitude });
        try {
          await fillAddressFromCoordinates(latitude, longitude, false);
          message.success('已使用当前位置填充坐标和详细地址');
        } finally {
          setResolving(false);
        }
      },
      (error) => {
        setResolving(false);
        message.error(error.message || '浏览器定位失败，请检查定位权限');
      },
      {
        enableHighAccuracy: true,
        timeout: 8000,
        maximumAge: 30000,
      },
    );
  };

  const fillAddressFromCoordinates = async (
    latitude: number,
    longitude: number,
    manageLoading = true,
  ) => {
    if (manageLoading) setResolving(true);
    try {
      const result = await checkinApi.reverseGeocode(latitude, longitude);
      form.setFieldsValue({
        latitude,
        longitude,
        address: buildAddress(result),
      });
      if (manageLoading) message.success('已根据坐标反查并填入详细地址');
    } finally {
      if (manageLoading) setResolving(false);
    }
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
      width: 160,
      render: (_: any, record: any) => (
        <Space>
          <Button type="link" onClick={() => edit(record)}>编辑</Button>
          {record.status === 'ACTIVE'
            ? <Button type="link" danger onClick={() => disable(record.id)}>停用</Button>
            : <span>—</span>}
        </Space>
      ),
    },
  ];

  return (
    <div>
      <Card
        title={editing ? `校准打卡点：${editing.name}` : '新增打卡点'}
        extra={editing ? <Button onClick={cancelEdit}>取消编辑</Button> : null}
        style={{ marginBottom: 16 }}
      >
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
            <Space>
              <Button onClick={geocode} loading={resolving}>按地址解析坐标</Button>
              <Button onClick={reverseByCoordinates} loading={resolving}>按坐标反查地址</Button>
              <Button onClick={useCurrentLocation} loading={resolving}>使用当前位置</Button>
              <Button type="primary" htmlType="submit">{editing ? '保存校准' : '创建'}</Button>
            </Space>
          </Form.Item>
        </Form>
      </Card>
      <Card title="打卡点列表">
        <Table rowKey="id" columns={columns} dataSource={data} pagination={{ pageSize: 10 }} />
      </Card>
    </div>
  );
};

function buildAddress(data: any) {
  const formatted = `${data?.formattedAddress ?? ''}`.trim();
  if (formatted) return formatted;
  return [
    data?.province,
    data?.city,
    data?.district,
    data?.town,
    data?.street,
    data?.streetNumber,
  ]
    .map((item) => `${item ?? ''}`.trim())
    .filter(Boolean)
    .join('');
}

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
