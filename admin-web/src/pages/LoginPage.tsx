import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { Form, Input, Button, Card, message, Typography } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { authApi } from '../api/auth';
import { useAuthStore } from '../store/useAuthStore';

const { Title, Text } = Typography;

const LoginPage: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();
  const login = useAuthStore((s) => s.login);

  const onFinish = async (values: { studentId: string; password: string }) => {
    setLoading(true);
    try {
      const res = await authApi.login(values);
      login(res.accessToken, res.userId, res.realName, res.role);
      message.success(`欢迎回来，${res.realName}`);
      navigate('/');
    } catch {
      // 错误已在拦截器处理
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', justifyContent: 'center',
      alignItems: 'center', background: 'linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%)',
    }}>
      <Card style={{ width: 420, borderRadius: 12, boxShadow: '0 8px 40px rgba(0,0,0,0.3)' }}>
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <Title level={2} style={{ marginBottom: 4 }}>🎓 AI思政管理平台</Title>
          <Text type="secondary">南华大学计算机学院</Text>
        </div>
        <Form name="login" size="large" onFinish={onFinish}>
          <Form.Item name="studentId" rules={[{ required: true, message: '请输入工号' }]}>
            <Input prefix={<UserOutlined />} placeholder="工号" />
          </Form.Item>
          <Form.Item name="password" rules={[{ required: true, message: '请输入密码' }]}>
            <Input.Password prefix={<LockOutlined />} placeholder="密码" />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={loading} block>
              登 录
            </Button>
          </Form.Item>
          <div style={{ textAlign: 'center', marginTop: 8 }}>
            <Text type="secondary">还没有账号？</Text>
            <Link to="/register"> 立即注册</Link>
          </div>
        </Form>
      </Card>
    </div>
  );
};

export default LoginPage;
