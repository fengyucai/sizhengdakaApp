import React from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import { Layout, Menu, Button, Avatar, Dropdown, theme } from 'antd';
import {
  DashboardOutlined, HomeOutlined, BookOutlined,
  GlobalOutlined, FileTextOutlined, AlertOutlined,
  BarChartOutlined, LogoutOutlined, UserOutlined,
  AuditOutlined,
} from '@ant-design/icons';
import { useAuthStore } from '../store/useAuthStore';

const { Header, Sider, Content } = Layout;

const menuItems = [
  { key: '/', icon: <DashboardOutlined />, label: '工作台' },
  { key: '/dorm', icon: <HomeOutlined />, label: '查寝管理' },
  { key: '/class', icon: <BookOutlined />, label: '课堂管理' },
  { key: '/intern', icon: <GlobalOutlined />, label: '实习监控' },
  { key: '/leave', icon: <FileTextOutlined />, label: '请假审批' },
  { key: '/appeals', icon: <AuditOutlined />, label: '申诉审核' },
  { key: '/alerts', icon: <AlertOutlined />, label: '预警中心' },
  { key: '/reports', icon: <BarChartOutlined />, label: '数据报表' },
];

const MainLayout: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { realName, logout } = useAuthStore();
  const { token: themeToken } = theme.useToken();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const userMenu = [
    { key: 'logout', icon: <LogoutOutlined />, label: '退出登录', onClick: handleLogout },
  ];

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider width={220} theme="dark">
        <div style={{
          height: 64, display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#fff', fontSize: 18, fontWeight: 'bold', borderBottom: '1px solid #333',
        }}>
          🎓 AI思政管理
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[location.pathname]}
          items={menuItems}
          onClick={({ key }) => navigate(key)}
        />
      </Sider>
      <Layout>
        <Header style={{
          background: themeToken.colorBgContainer,
          padding: '0 24px', display: 'flex', justifyContent: 'flex-end',
          alignItems: 'center', borderBottom: '1px solid #f0f0f0',
        }}>
          <Dropdown menu={{ items: userMenu }}>
            <Button type="text" icon={<Avatar size="small" icon={<UserOutlined />} />}>
              {realName || '管理员'}
            </Button>
          </Dropdown>
        </Header>
        <Content style={{ margin: 16 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
};

export default MainLayout;
