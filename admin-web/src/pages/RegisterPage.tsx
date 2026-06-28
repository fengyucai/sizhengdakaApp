import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { Form, Input, Button, Card, message, Typography } from 'antd';
import { UserOutlined, LockOutlined, PhoneOutlined, IdcardOutlined } from '@ant-design/icons';
import request from '../api/request';

const { Title, Text } = Typography;

const RegisterPage: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const onFinish = async (values: {
    studentId: string;
    realName: string;
    password: string;
    confirmPassword: string;
    phone?: string;
  }) => {
    if (values.password !== values.confirmPassword) {
      message.error('两次输入的密码不一致');
      return;
    }
    setLoading(true);
    try {
      const data = await request.post<any, {
        accessToken: string;
        userId: string;
        realName: string;
        role: string;
      }>('/auth/register', {
        studentId: values.studentId,
        realName: values.realName,
        password: values.password,
        phone: values.phone || '',
      });
      // Interceptor unwraps: {code:200, data:{...}} → data directly
      message.success(`注册成功！欢迎，${data.realName}`);
      localStorage.setItem('accessToken', data.accessToken);
      localStorage.setItem('userId', data.userId);
      localStorage.setItem('realName', data.realName);
      localStorage.setItem('role', data.role);
      navigate('/');
    } catch (err: any) {
      message.error(err?.message || '注册失败，请检查网络连接');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', justifyContent: 'center',
      alignItems: 'center', background: 'linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%)',
    }}>
      <Card style={{ width: 440, borderRadius: 12, boxShadow: '0 8px 40px rgba(0,0,0,0.3)' }}>
        <div style={{ textAlign: 'center', marginBottom: 24 }}>
          <Title level={2} style={{ marginBottom: 4 }}>📝 用户注册</Title>
          <Text type="secondary">南华大学计算机学院 — AI思政打卡平台</Text>
        </div>
        <Form name="register" size="large" onFinish={onFinish} layout="vertical">
          <Form.Item name="studentId" rules={[
            { required: true, message: '请输入学号' },
            { pattern: /^\d{6,12}$/, message: '学号格式不正确 (6-12位数字)' },
          ]}>
            <Input prefix={<IdcardOutlined />} placeholder="学号 (如: 20240101)" />
          </Form.Item>
          <Form.Item name="realName" rules={[{ required: true, message: '请输入真实姓名' }]}>
            <Input prefix={<UserOutlined />} placeholder="真实姓名" />
          </Form.Item>
          <Form.Item name="phone" rules={[
            { pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确' },
          ]}>
            <Input prefix={<PhoneOutlined />} placeholder="手机号 (选填)" />
          </Form.Item>
          <Form.Item name="password" rules={[
            { required: true, message: '请输入密码' },
            { min: 6, message: '密码至少6位' },
          ]}>
            <Input.Password prefix={<LockOutlined />} placeholder="密码 (至少6位)" />
          </Form.Item>
          <Form.Item name="confirmPassword" rules={[
            { required: true, message: '请确认密码' },
          ]}>
            <Input.Password prefix={<LockOutlined />} placeholder="确认密码" />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={loading} block>
              注 册
            </Button>
          </Form.Item>
          <div style={{ textAlign: 'center' }}>
            <Text>已有账号？</Text>
            <Link to="/login"> 立即登录</Link>
          </div>
        </Form>
      </Card>
    </div>
  );
};

export default RegisterPage;
