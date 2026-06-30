<template>
  <div class="screen">
    <!-- 顶部标题 -->
    <header class="header">
      <h1>🎓 南华大学计算机学院 — AI思政管理数据看板</h1>
      <span class="time">{{ currentTime }}</span>
    </header>

    <!-- 核心指标 -->
    <section class="stats-row">
      <div class="stat-card" v-for="s in stats" :key="s.label">
        <div class="stat-icon" :style="{ background: s.color }">{{ s.icon }}</div>
        <div class="stat-info">
          <div class="stat-value">{{ s.value }}<small>{{ s.unit }}</small></div>
          <div class="stat-label">{{ s.label }}</div>
        </div>
      </div>
    </section>

    <!-- 图表区 + 预警 -->
    <section class="middle-row">
      <div class="card chart-card">
        <h3>📊 查寝打卡趋势 (近7天)</h3>
        <div ref="dormChart" class="chart"></div>
      </div>
      <div class="card chart-card">
        <h3>📚 上课出勤趋势 (近7天)</h3>
        <div ref="classChart" class="chart"></div>
      </div>
      <div class="card alert-card">
        <h3>⚠️ 实时预警</h3>
        <div class="alert-list">
          <div v-for="a in alerts" :key="a.id" class="alert-item" :class="a.level">
            <span class="alert-time">{{ a.time }}</span>
            <span class="alert-user">{{ a.user }}</span>
            <span class="alert-text">{{ a.text }}</span>
            <span class="alert-tag" :class="a.level">{{ a.level === 'red' ? '🔴' : '🟡' }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- 底部：年级对比 -->
    <section class="bottom-row">
      <div class="card chart-card">
        <h3>🏫 年级出勤对比</h3>
        <div ref="gradeChart" class="chart"></div>
      </div>
      <div class="card summary-card">
        <h3>📋 今日汇总</h3>
        <div class="summary-grid">
          <div class="summary-item">
            <div class="s-val green">{{ summary.dormRate }}%</div>
            <div class="s-label">查寝完成率</div>
          </div>
          <div class="summary-item">
            <div class="s-val blue">{{ summary.classRate }}%</div>
            <div class="s-label">课堂出勤率</div>
          </div>
          <div class="summary-item">
            <div class="s-val purple">{{ summary.internCheck }}人</div>
            <div class="s-label">实习在岗</div>
          </div>
          <div class="summary-item">
            <div class="s-val red">{{ summary.pendingAlerts }}</div>
            <div class="s-label">待处理预警</div>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, reactive } from 'vue';
import * as echarts from 'echarts';
import { login, fetchAlerts, fetchStats, fetchTrend } from '../api';

const currentTime = ref('');
let timer: number;
let refreshTimer: number;

const stats = reactive([
  { label: '应查寝', value: 0, unit: '人', icon: '🏠', color: '#1890ff' },
  { label: '已打卡', value: 0, unit: '人', icon: '✅', color: '#52c41a' },
  { label: '出勤率', value: 0, unit: '%', icon: '📚', color: '#722ed1' },
  { label: '预警', value: 0, unit: '条', icon: '⚠️', color: '#ff4d4f' },
]);

const alerts = reactive<{ id: number; time: string; user: string; text: string; level: string }[]>([]);

const summary = reactive({
  dormRate: 0,
  classRate: 0,
  internCheck: 0,
  pendingAlerts: 0,
});

const apiConnected = ref(false);
const trendLabels = ref<string[]>([]);
const dormTrend = ref<number[]>([]);
const classTrend = ref<number[]>([]);
const internTrend = ref<number[]>([]);

/** 从后端拉取实时数据 */
async function refreshData() {
  try {
    // 使用辅导员账号获取管理数据
    const d = await login('T2024001', '123456');
    const token = d.accessToken;
    const [statsData, trendData, alertData] = await Promise.all([
      fetchStats(token),
      fetchTrend(token, 7),
      fetchAlerts(token),
    ]);
    apiConnected.value = true;

    if (statsData) {
      stats[0].value = (statsData as any).studentTotal || 0;
      stats[1].value = (statsData as any).dormChecked || 0;
      stats[2].value = (statsData as any).classRate || 0;
      stats[3].value = (statsData as any).pendingAlerts || 0;
      summary.dormRate = (statsData as any).dormRate || 0;
      summary.classRate = (statsData as any).classRate || 0;
      summary.internCheck = (statsData as any).internChecked || 0;
      summary.pendingAlerts = (statsData as any).pendingAlerts || 0;
    }
    const trend = Array.isArray(trendData) ? trendData : [];
    trendLabels.value = trend.map((item: any) => String(item.date || ''));
    dormTrend.value = trend.map((item: any) => Number(item.dormRate || 0));
    classTrend.value = trend.map((item: any) => Number(item.classRate || 0));
    internTrend.value = trend.map((item: any) => Number(item.internRate || 0));

    alerts.splice(0, alerts.length);
    for (const item of Array.isArray(alertData) ? alertData : []) {
      alerts.push({
        id: Number(item.id || 0),
        time: String(item.time || ''),
        user: String(item.title || ''),
        text: String(item.content || ''),
        level: item.level === 'RED' ? 'red' : 'yellow',
      });
    }
    updateCharts();
  } catch {
    apiConnected.value = false;
    stats.forEach((item) => (item.value = 0));
    summary.dormRate = 0;
    summary.classRate = 0;
    summary.internCheck = 0;
    summary.pendingAlerts = 0;
    alerts.splice(0, alerts.length);
    trendLabels.value = [];
    dormTrend.value = [];
    classTrend.value = [];
    internTrend.value = [];
    updateCharts();
  }
}

const dormChart = ref<HTMLDivElement>();
const classChart = ref<HTMLDivElement>();
const gradeChart = ref<HTMLDivElement>();

function makeLineChart(el: HTMLDivElement, data: number[], color: string) {
  const chart = echarts.init(el);
  chart.setOption({
    grid: { top: 10, right: 10, bottom: 20, left: 40 },
    xAxis: { type: 'category', data: trendLabels.value, axisLabel: { color: '#aaa' } },
    yAxis: { type: 'value', min: 0, max: 100, axisLabel: { color: '#aaa' } },
    series: [{ data, type: 'line', smooth: true, symbol: 'circle', symbolSize: 6, lineStyle: { color, width: 2 }, itemStyle: { color }, areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color }, { offset: 1, color: 'transparent' }]) } }],
  });
  return chart;
}

let charts: echarts.ECharts[] = [];
let dormChartInstance: echarts.ECharts | null = null;
let classChartInstance: echarts.ECharts | null = null;
let gradeChartInstance: echarts.ECharts | null = null;

function updateCharts() {
  if (dormChartInstance) {
    dormChartInstance.setOption({
      xAxis: { data: trendLabels.value },
      series: [{ data: dormTrend.value }],
    });
  }
  if (classChartInstance) {
    classChartInstance.setOption({
      xAxis: { data: trendLabels.value },
      series: [{ data: classTrend.value }],
    });
  }
  if (gradeChartInstance) {
    gradeChartInstance.setOption({
      xAxis: { data: ['查寝', '上课', '实习'] },
      yAxis: { min: 0, max: 100 },
      series: [{ data: [summary.dormRate, summary.classRate, internTrend.value.at(-1) || 0] }],
    });
  }
}

onMounted(async () => {
  timer = window.setInterval(() => {
    currentTime.value = new Date().toLocaleString('zh-CN');
  }, 1000);

  if (dormChart.value) {
    dormChartInstance = makeLineChart(dormChart.value, dormTrend.value, '#1890ff');
    charts.push(dormChartInstance);
  }
  if (classChart.value) {
    classChartInstance = makeLineChart(classChart.value, classTrend.value, '#52c41a');
    charts.push(classChartInstance);
  }
  if (gradeChart.value) {
    const c = echarts.init(gradeChart.value);
    gradeChartInstance = c;
    c.setOption({
      grid: { top: 10, right: 10, bottom: 20, left: 40 },
      xAxis: { type: 'category', data: ['查寝', '上课', '实习'], axisLabel: { color: '#aaa' } },
      yAxis: { type: 'value', min: 0, max: 100, axisLabel: { color: '#aaa' } },
      series: [{ data: [0, 0, 0], type: 'bar', barWidth: 36, itemStyle: { borderRadius: [4, 4, 0, 0], color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: '#722ed1' }, { offset: 1, color: '#b37feb' }]) } }],
    });
    charts.push(c);
  }

  await refreshData();
  refreshTimer = window.setInterval(refreshData, 60000);
});

onUnmounted(() => {
  clearInterval(timer);
  clearInterval(refreshTimer);
  charts.forEach((c) => c.dispose());
});
</script>

<style scoped>
.screen {
  min-height: 100vh; background: #0a0e27; color: #e0e0e0;
  padding: 16px 24px; font-family: 'Microsoft YaHei', sans-serif;
}
.header { display: flex; justify-content: space-between; align-items: center; padding: 12px 0; border-bottom: 1px solid #1a1f3a; margin-bottom: 16px; }
.header h1 { font-size: 26px; font-weight: 700; background: linear-gradient(90deg, #4facfe, #00f2fe); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
.header .time { font-size: 16px; color: #8890b5; }
.stats-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 16px; }
.stat-card { background: #111633; border-radius: 10px; padding: 20px; display: flex; align-items: center; gap: 16px; border: 1px solid #1a1f3a; }
.stat-icon { width: 56px; height: 56px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 28px; }
.stat-value { font-size: 28px; font-weight: 700; color: #fff; }
.stat-value small { font-size: 14px; color: #8890b5; margin-left: 4px; font-weight: 400; }
.stat-label { font-size: 13px; color: #8890b5; margin-top: 2px; }
.middle-row { display: grid; grid-template-columns: 1fr 1fr 320px; gap: 16px; margin-bottom: 16px; }
.bottom-row { display: grid; grid-template-columns: 1fr 280px; gap: 16px; }
.card { background: #111633; border-radius: 10px; padding: 16px; border: 1px solid #1a1f3a; }
.card h3 { font-size: 15px; margin-bottom: 10px; color: #c0c6e0; }
.chart { height: 200px; }
.alert-list { display: flex; flex-direction: column; gap: 10px; max-height: 300px; overflow-y: auto; }
.alert-item { display: flex; align-items: center; gap: 8px; padding: 10px; border-radius: 8px; font-size: 13px; }
.alert-item.red { background: rgba(255, 77, 79, 0.12); border-left: 3px solid #ff4d4f; }
.alert-item.yellow { background: rgba(250, 173, 20, 0.12); border-left: 3px solid #faad14; }
.alert-time { color: #8890b5; min-width: 44px; }
.alert-user { color: #c0c6e0; min-width: 44px; font-weight: 600; }
.alert-text { flex: 1; color: #c0c6e0; }
.summary-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.summary-item { text-align: center; padding: 12px; background: rgba(255,255,255,0.03); border-radius: 8px; }
.s-val { font-size: 26px; font-weight: 700; }
.s-val.green { color: #52c41a; } .s-val.blue { color: #1890ff; }
.s-val.purple { color: #722ed1; } .s-val.red { color: #ff4d4f; }
.s-label { font-size: 12px; color: #8890b5; margin-top: 4px; }
</style>
