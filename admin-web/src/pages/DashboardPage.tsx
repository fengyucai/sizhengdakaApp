import React, { useEffect, useState } from 'react';
import { Card, Row, Col, Statistic, Table, Tag } from 'antd';
import {
  HomeOutlined, BookOutlined, GlobalOutlined,
  AlertOutlined,
} from '@ant-design/icons';
import { checkinApi } from '../api/checkin';
import type { TodayStats } from '../api/checkin';

const DashboardPage: React.FC = () => {
  const [dashboard, setDashboard] = useState<TodayStats>();
  const [alerts, setAlerts] = useState<any[]>([]);
  const [trend, setTrend] = useState<any[]>([]);

  useEffect(() => {
    checkinApi.getDashboard().then(setDashboard).catch(() => {});
    checkinApi.getAlerts().then(setAlerts).catch(() => {});
    checkinApi.getTrendReport().then(setTrend).catch(() => {});
  }, []);

  const stats = [
    { title: '今日查寝', value: dashboard?.dormChecked ?? 0, suffix: '已打卡', icon: <HomeOutlined />, color: '#1890ff' },
    { title: '今日上课', value: dashboard?.classChecked ?? 0, suffix: '已签到', icon: <BookOutlined />, color: '#52c41a' },
    { title: '实习在岗', value: dashboard?.internChecked ?? 0, suffix: '人', icon: <GlobalOutlined />, color: '#722ed1' },
    { title: '待处理预警', value: dashboard?.pendingAlerts ?? 0, suffix: '条', icon: <AlertOutlined />, color: '#ff4d4f' },
  ];

  const alertColumns = [
    { title: '时间', dataIndex: 'time', width: 120 },
    { title: '标题', dataIndex: 'title', width: 120 },
    { title: '内容', dataIndex: 'content' },
    {
      title: '等级', dataIndex: 'level', width: 100,
      render: (v: string) => <Tag color={v === 'RED' ? 'red' : 'gold'}>{v === 'RED' ? '红色预警' : '黄色预警'}</Tag>,
    },
  ];

  return (
    <div>
      <Row gutter={16} style={{ marginBottom: 16 }}>
        {stats.map((s) => (
          <Col span={6} key={s.title}>
            <Card>
              <Statistic
                title={s.title}
                value={s.value}
                suffix={s.suffix}
                prefix={<span style={{ color: s.color, fontSize: 24 }}>{s.icon}</span>}
              />
            </Card>
          </Col>
        ))}
      </Row>
      <Row gutter={16}>
        <Col span={12}>
          <Card title="📊 出勤趋势 (近7天)">
            <div style={{ height: 200, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 10 }}>
              {(trend.length ? trend : []).map((item) => {
                const avg = Math.round(((item.dormRate || 0) + (item.classRate || 0) + (item.internRate || 0)) / 3);
                return (
                  <div key={item.date} style={{ display: 'grid', gridTemplateColumns: '76px 1fr 42px', alignItems: 'center', gap: 8 }}>
                    <span style={{ color: '#666' }}>{String(item.date).slice(5)}</span>
                    <div style={{ height: 10, background: '#f0f0f0', borderRadius: 6, overflow: 'hidden' }}>
                      <div style={{ width: `${avg}%`, height: '100%', background: '#1a73e8' }} />
                    </div>
                    <span>{avg}%</span>
                  </div>
                );
              })}
              {!trend.length && <div style={{ color: '#999', textAlign: 'center' }}>暂无趋势数据</div>}
            </div>
          </Card>
        </Col>
        <Col span={12}>
          <Card title="⚠️ 最新预警" extra={<a>查看全部 →</a>}>
            <Table columns={alertColumns} dataSource={alerts} pagination={false} size="small" />
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default DashboardPage;
