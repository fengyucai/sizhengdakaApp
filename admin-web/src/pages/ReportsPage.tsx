import React, { useEffect, useState } from 'react';
import { Card, Row, Col, Button, DatePicker, Space, Statistic } from 'antd';
import { DownloadOutlined, FileTextOutlined } from '@ant-design/icons';
import { checkinApi } from '../api/checkin';

const ReportsPage: React.FC = () => {
  const [report, setReport] = useState<any>({});

  useEffect(() => {
    checkinApi.getWeeklyReport().then(setReport).catch(() => {});
  }, []);

  const downloadReport = async (path: string, filename: string) => {
    const token = localStorage.getItem('accessToken');
    const res = await fetch(`http://localhost:8080${path}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    });
    if (!res.ok) return;
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${filename}-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div>
      <Card style={{ marginBottom: 16 }}>
        <Space>
          <DatePicker picker="week" />
          <Button type="primary" icon={<DownloadOutlined />} onClick={() => downloadReport('/manage/report/weekly/export', 'weekly-checkin-report')}>导出周报</Button>
          <Button icon={<FileTextOutlined />} onClick={() => downloadReport('/manage/report/monthly/export', 'monthly-checkin-report')}>导出月报</Button>
        </Space>
      </Card>
      <Row gutter={16}>
        <Col span={8}>
          <Card title="📊 查寝周报">
            <Statistic title="平均打卡率" value={report.dormRate ?? 0} suffix="%" />
            <div style={{ height: 150, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#999' }}>
              图表区 (接入后端后渲染)
            </div>
          </Card>
        </Col>
        <Col span={8}>
          <Card title="📚 出勤周报">
            <Statistic title="平均出勤率" value={report.classRate ?? 0} suffix="%" />
            <div style={{ height: 150, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#999' }}>
              图表区 (接入后端后渲染)
            </div>
          </Card>
        </Col>
        <Col span={8}>
          <Card title="💼 实习周报">
            <Statistic title="日志提交率" value={report.internRate ?? 0} suffix="%" />
            <div style={{ height: 150, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#999' }}>
              图表区 (接入后端后渲染)
            </div>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default ReportsPage;
