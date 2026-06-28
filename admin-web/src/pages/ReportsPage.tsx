import React, { useEffect, useState } from 'react';
import { Card, Row, Col, Button, DatePicker, Space, Statistic } from 'antd';
import { DownloadOutlined, FileTextOutlined } from '@ant-design/icons';
import { checkinApi } from '../api/checkin';

const ReportsPage: React.FC = () => {
  const [report, setReport] = useState<any>({});
  const [trend, setTrend] = useState<any[]>([]);

  useEffect(() => {
    checkinApi.getWeeklyReport().then(setReport).catch(() => {});
    checkinApi.getTrendReport().then(setTrend).catch(() => {});
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
            <TrendBars data={trend} field="dormRate" />
          </Card>
        </Col>
        <Col span={8}>
          <Card title="📚 出勤周报">
            <Statistic title="平均出勤率" value={report.classRate ?? 0} suffix="%" />
            <TrendBars data={trend} field="classRate" />
          </Card>
        </Col>
        <Col span={8}>
          <Card title="💼 实习周报">
            <Statistic title="日志提交率" value={report.internRate ?? 0} suffix="%" />
            <TrendBars data={trend} field="internRate" />
          </Card>
        </Col>
      </Row>
    </div>
  );
};

const TrendBars: React.FC<{ data: any[]; field: string }> = ({ data, field }) => (
  <div style={{ height: 150, display: 'flex', alignItems: 'end', gap: 8, paddingTop: 16 }}>
    {data.map((item) => (
      <div key={`${field}-${item.date}`} style={{ flex: 1, textAlign: 'center' }}>
        <div style={{ height: 96, display: 'flex', alignItems: 'end', justifyContent: 'center' }}>
          <div
            title={`${item.date}: ${item[field] ?? 0}%`}
            style={{
              width: '70%',
              height: `${Math.max(4, item[field] ?? 0)}%`,
              background: '#1a73e8',
              borderRadius: '4px 4px 0 0',
            }}
          />
        </div>
        <div style={{ fontSize: 11, color: '#999' }}>{String(item.date).slice(5)}</div>
      </div>
    ))}
    {!data.length && <div style={{ color: '#999', margin: 'auto' }}>暂无趋势数据</div>}
  </div>
);

export default ReportsPage;
