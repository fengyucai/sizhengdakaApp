import React, { useEffect, useState } from 'react';
import { Card, Row, Col, Button, DatePicker, Space, Statistic } from 'antd';
import { DownloadOutlined, FileTextOutlined } from '@ant-design/icons';
import { checkinApi } from '../api/checkin';

const ReportsPage: React.FC = () => {
  const [report, setReport] = useState<any>({});

  useEffect(() => {
    checkinApi.getWeeklyReport().then(setReport).catch(() => {});
  }, []);

  return (
    <div>
      <Card style={{ marginBottom: 16 }}>
        <Space>
          <DatePicker picker="week" />
          <Button type="primary" icon={<DownloadOutlined />}>生成周报</Button>
          <Button icon={<FileTextOutlined />}>生成月报</Button>
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
