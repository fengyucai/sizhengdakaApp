# 「AI思政」辅助APP — 技术需求文档

---

## 文档信息

| 项目 | 详情 |
|------|------|
| **项目名称** | AI思政辅助APP（南华·思政通） |
| **文档类型** | 技术需求文档（TRD） |
| **文档版本** | V1.0 |
| **适用对象** | 开发团队（学生小组）、企业导师（代码审查）、校内导师（技术方案评审） |
| **关联文档** | [PRD_AI思政打卡APP_产品需求文档](./PRD_AI思政打卡APP_产品需求文档.md) |

---

## 目录

1. [技术架构总览](#1-技术架构总览)
2. [技术选型方案](#2-技术选型方案)
3. [前端技术规范](#3-前端技术规范)
4. [后端技术规范](#4-后端技术规范)
5. [AI能力集成方案](#5-ai能力集成方案)
6. [数据库设计](#6-数据库设计)
7. [API接口设计](#7-api接口设计)
8. [安全技术方案](#8-安全技术方案)
9. [部署与运维](#9-部署与运维)
10. [测试策略](#10-测试策略)
11. [开发规范与工具链](#11-开发规范与工具链)
12. [附录](#12-附录)

---

## 1. 技术架构总览

### 1.1 系统架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                          客户端层 (Client)                        │
├─────────────────┬─────────────────┬──────────────────────────────┤
│  学生APP         │  辅导员Web端     │  数据大屏                      │
│  (Flutter/RN)   │  (React/Vue)    │  (ECharts/DataV)             │
└────────┬────────┴────────┬────────┴──────────┬───────────────────┘
         │                 │                   │
         └─────────────────┼───────────────────┘
                           │  HTTPS/TLS 1.3
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                        网关层 (Gateway)                           │
│                   Nginx / Kong API Gateway                       │
│           限流 · 鉴权 · 日志 · 负载均衡 · 动静分离                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      应用服务层 (Application)                     │
├──────────────┬──────────────┬──────────────┬────────────────────┤
│  用户服务      │  打卡服务      │  通知服务      │  AI服务            │
│  · 注册/登录   │  · 查寝打卡    │  · 推送管理    │  · 人脸识别引擎     │
│  · 权限管理    │  · 上课打卡    │  · 消息模板    │  · 活体检测        │
│  · 班级管理    │  · 实习打卡    │  · 预警规则    │  · 异常检测        │
│  · 请假审批    │  · 考勤统计    │               │  · 定位验证        │
└──────────────┴──────────────┴──────────────┴────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        数据层 (Data)                              │
├──────────────┬──────────────┬──────────────┬────────────────────┤
│ SQL Server   │  Redis 7     │  MinIO/OSS   │  Elasticsearch     │
│  · 业务数据   │  · 会话缓存   │  · 图片存储   │  · 日志搜索         │
│  · 事务支持   │  · 热点数据   │  · 文件归档   │  · 审计分析         │
└──────────────┴──────────────┴──────────────┴────────────────────┘
```

### 1.2 技术架构原则

| 原则 | 说明 |
|------|------|
| **前后端分离** | 前端与后端完全解耦，通过RESTful API通信 |
| **微服务思想** | 按功能域拆分服务模块，各团队可独立开发部署（不强制完整微服务，初期可采用模块化单体） |
| **AI可替换** | AI能力通过统一接口抽象，支持切换不同第三方AI服务商（百度AI / 腾讯AI / 阿里云AI） |
| **移动优先** | 学生端为移动原生体验，优先考虑弱网环境下的可用性 |
| **安全第一** | 人脸数据/位置数据全链路加密，满足个人信息保护合规要求 |
| **成本可控** | 优先使用开源技术栈与学校现有基础设施 |

---

## 2. 技术选型方案

### 2.1 推荐技术栈（方案A — 推荐）

| 层次 | 技术 | 版本 | 选型理由 |
|------|------|------|----------|
| **移动端** | Flutter | 3.24+ | 一套代码双端运行(iOS+Android)；Dart语言易学；UI表现力强；适合学生团队 |
| **管理Web端** | React + Ant Design | React 18+ / AntD 5 | 组件生态丰富；适合快速搭建管理后台；学生课程中学过React |
| **数据大屏** | Vue 3 + ECharts + DataV | Vue 3.4+ | 可视化生态成熟；大屏模板丰富 |
| **后端框架** | Spring Boot | 3.3+ / Java 17 | 学校教学主流框架；生态成熟；适合企业级开发 |
| **AI能力** | 百度AI SDK / 自研 | — | 人脸识别免费额度充足；文档齐全 |
| **数据库** | SQL Server | 2019+ | Windows生态原生支持；学校现有基础设施；与.NET/Java均良好兼容 |
| **缓存** | Redis | 7.0+ | 会话存储、热点数据缓存、分布式锁 |
| **对象存储** | MinIO | 最新稳定版 | 开源S3兼容；可部署在校内服务器；替代阿里云OSS |
| **消息队列** | RabbitMQ | 3.13+ | 异步通知、打卡事件削峰 |
| **API网关** | Nginx + Spring Cloud Gateway | — | 反向代理 + 限流 + 鉴权 |

### 2.2 备选技术栈（方案B — 轻量级）

适用于时间紧张或团队前端能力偏弱的情况：

| 层次 | 技术 | 说明 |
|------|------|------|
| **移动端** | UniApp (Vue) | 更快上手，但性能略低于Flutter |
| **管理端** | Vue 3 + Element Plus | Vue生态，轻量 |
| **后端** | Python FastAPI | AI集成更自然（Python生态），但企业工程化不如Spring Boot |
| **数据库** | PostgreSQL | 功能更丰富，开源免费 |

### 2.3 选型建议

> **推荐采用方案A**：Flutter + Spring Boot + React + SQL Server + Redis + 百度AI
>
> 理由：① 与企业导师侧的技术栈对齐（软件园多使用Java/Spring生态）；② 学生课程体系中有Java/React基础，学习曲线可控；③ Flutter一套代码双端发布，减少移动端开发工作量；④ 百度AI人脸识别提供学生免费额度，成本可控；⑤ SQL Server为学校现有基础设施，无需额外部署成本。

---

## 3. 前端技术规范

### 3.1 移动端（Flutter）

#### 3.1.1 项目结构

```
lib/
├── main.dart                    # 应用入口
├── app.dart                     # MaterialApp配置
├── config/
│   ├── app_config.dart          # 环境配置
│   ├── api_config.dart          # API地址配置
│   └── theme.dart               # 主题定义
├── models/                      # 数据模型
│   ├── user_model.dart
│   ├── checkin_model.dart
│   └── notification_model.dart
├── services/                    # 业务服务
│   ├── api_service.dart         # HTTP请求封装
│   ├── auth_service.dart        # 认证服务
│   ├── location_service.dart    # 定位服务
│   ├── face_service.dart        # 人脸识别服务
│   └── storage_service.dart     # 本地存储
├── pages/                       # 页面
│   ├── login/
│   ├── home/
│   ├── checkin_dorm/            # 查寝打卡
│   ├── checkin_class/           # 上课打卡
│   ├── checkin_intern/          # 实习打卡
│   ├── profile/                 # 个人中心
│   └── message/                 # 消息中心
├── widgets/                     # 公共组件
│   ├── face_capture_widget.dart # 人脸采集组件
│   ├── location_picker.dart     # 定位选择器
│   └── countdown_timer.dart     # 倒计时组件
└── utils/                       # 工具类
    ├── validators.dart
    ├── date_utils.dart
    └── file_utils.dart
```

#### 3.1.2 关键技术要求

| 要求 | 说明 | 实现方案 |
|------|------|----------|
| GPS定位 | 获取学生当前位置坐标 | `geolocator` 插件；精度设为 `high`；超时10秒 |
| 地图展示 | 打卡页显示位置与电子围栏关系 | `flutter_map` + OpenStreetMap（免费，免Key）或高德地图SDK |
| 相机调用 | 人脸识别拍照 | `camera` 插件；前置摄像头；照片质量压缩至 ≤ 500KB 后上传 |
| 二维码扫描 | 课堂动态码签到 | `mobile_scanner` 插件；支持连续扫描模式 |
| 本地缓存 | 离线数据暂存 | `sqflite`（SQLite）；存储离线打卡记录，联网自动同步 |
| 推送通知 | 打卡提醒/预警通知 | 极光推送 (JPush) 或 Firebase Cloud Messaging |
| 网络状态监听 | 弱网提示与离线切换 | `connectivity_plus` 插件 |
| 安全存储 | Token、敏感配置本地存储 | `flutter_secure_storage` |

#### 3.1.3 性能要求

- 页面切换动画帧率 ≥ 60fps
- 列表滚动帧率 ≥ 58fps
- 图片懒加载 + 内存缓存（最大缓存200MB）
- Widget 合理拆分，避免不必要的 rebuild

### 3.2 管理Web端（React + Ant Design）

#### 3.2.1 项目结构

```
src/
├── components/           # 公共组件
│   ├── Layout/
│   ├── StatCard/         # 统计卡片
│   └── DataTable/        # 数据表格
├── pages/
│   ├── Dashboard/        # 工作台首页
│   ├── DormManage/       # 查寝管理
│   ├── ClassManage/      # 课堂管理
│   ├── InternManage/     # 实习管理
│   ├── LeaveApproval/    # 请假审批
│   └── Reports/          # 数据报表
├── services/             # API请求
├── hooks/                # 自定义Hooks
├── store/                # 状态管理（Zustand/Redux Toolkit）
├── utils/
└── types/                # TypeScript类型定义
```

#### 3.2.2 关键技术要求

| 要求 | 说明 |
|------|------|
| 状态管理 | Zustand（轻量）或 Redux Toolkit（功能完善） |
| HTTP请求 | Axios + 拦截器（Token自动注入、401重定向登录） |
| 路由 | React Router v6；权限路由守卫 |
| 表格 | Ant Design ProTable（自带分页/搜索/导出） |
| 图表 | ECharts + echarts-for-react |
| 文件导出 | ExcelJS（导出考勤报表） |
| 权限控制 | RBAC：管理员/辅导员/教师三种角色，菜单级权限 |

### 3.3 数据大屏

| 要求 | 说明 |
|------|------|
| 框架 | Vue 3 + Vite |
| 可视化 | ECharts 5 + DataV |
| 自适应 | CSS `transform: scale` + 媒体查询，适配 1920×1080 ~ 3840×2160 |
| 数据刷新 | WebSocket 推送 + 定时轮询（30秒）双通道 |
| 主题 | 深色科技蓝主题 |

---

## 4. 后端技术规范

### 4.1 后端架构

```
┌─────────────────────────────────────────────┐
│              Spring Boot Application         │
├─────────────────────────────────────────────┤
│  Controller 层  │  @RestController           │
│                 │  参数校验 (JSR-303)         │
│                 │  统一响应封装 (Result<T>)   │
├─────────────────┼───────────────────────────┤
│  Service 层     │  业务逻辑编排               │
│                 │  事务管理 (@Transactional)  │
├─────────────────┼───────────────────────────┤
│  Repository 层  │  MyBatis-Plus / JPA        │
│                 │  SQL Server JDBC Driver    │
│                 │  读写分离（可选）            │
├─────────────────┼───────────────────────────┤
│  Infrastructure │  Redis · RabbitMQ · MinIO  │
│                 │  AI SDK · 推送SDK          │
└─────────────────────────────────────────────┘
```

### 4.2 模块划分

| 模块 | 职责 | 核心类/接口 |
|------|------|------------|
| `user-service` | 用户注册/登录、角色权限、班级管理、人脸注册 | `UserController`, `AuthService`, `FaceService` |
| `checkin-service` | 查寝打卡、上课打卡、实习打卡的核心逻辑 | `CheckinController`, `LocationValidator`, `CheckinStatistics` |
| `leave-service` | 请假申请/审批流程 | `LeaveController`, `LeaveWorkflowService` |
| `notification-service` | 消息推送、预警规则引擎 | `NotificationService`, `AlertRuleEngine` |
| `report-service` | 考勤统计报表生成与导出 | `ReportController`, `ExcelExportService` |
| `ai-service` | AI能力统一封装（人脸识别、活体检测、异常检测） | `FaceRecognitionProvider`, `LivenessDetector` |

### 4.3 关键技术要求

| 要求 | 实现方案 |
|------|----------|
| **统一响应格式** | `{ "code": 200, "message": "success", "data": {...}, "timestamp": 1719417600 }` |
| **全局异常处理** | `@RestControllerAdvice` + 自定义业务异常枚举 |
| **API接口鉴权** | JWT（Access Token 2h + Refresh Token 7d） |
| **接口限流** | 打卡类接口：单用户 1次/10秒；全局 500 QPS |
| **分布式锁** | Redis Redisson；防止同一用户重复提交打卡 |
| **异步任务** | `@Async` + 线程池；用于通知推送、报表生成 |
| **消息队列** | RabbitMQ：打卡事件 → 通知服务异步发送提醒 |
| **参数校验** | Hibernate Validator；手机号/学号格式校验 |
| **日志规范** | SLF4J + Logback；操作日志落库审计 |
| **API文档** | Knife4j (Swagger增强)；自动生成API文档 |

### 4.4 打卡核心流程（以查寝为例）

```
┌──────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────┐
│  APP端    │     │  API Gateway  │     │  Checkin Svc  │     │  AI Svc   │
└────┬─────┘     └──────┬───────┘     └──────┬───────┘     └────┬─────┘
     │  1. POST /checkin/dorm               │                   │
     │  {location, faceImage}               │                   │
     │─────────────────────────────────────→│                   │
     │                  │                   │  2. 验证打卡时段     │
     │                  │                   │  3. 验证地理位置     │
     │                  │                   │  4. 调用人脸识别     │
     │                  │                   │──────────────────→│
     │                  │                   │  5. 返回相似度     │
     │                  │                   │←──────────────────│
     │                  │                   │  6. 相似度 ≥ 85%？  │
     │                  │                   │  7. 记录打卡成功     │
     │                  │                   │  8. 更新缓存状态     │
     │  9. 返回打卡结果  │                   │                   │
     │←─────────────────────────────────────│                   │
     │                  │                   │  10. 异步发送通知    │
     │                  │                   │  (MQ → Notification) │
```

### 4.5 缓存策略

| 数据 | 缓存位置 | TTL | 说明 |
|------|----------|-----|------|
| 用户会话Token | Redis | 2h | JWT验证、黑名单检查 |
| 今日打卡状态 | Redis | 当天24:00过期 | 快速判断是否已打卡 |
| 人脸特征向量 | Redis | 24h | 减少数据库查询 |
| 课程表信息 | Redis | 1h | 高频读取，低频变更 |
| 电子围栏配置 | Redis | 1h | 各打卡点坐标范围 |
| 接口限流计数 | Redis | 滑动窗口 | IP/用户级别限流 |

---

## 5. AI能力集成方案

### 5.1 AI能力总览

| AI能力 | 应用场景 | 推荐方案 | 自研备选 |
|--------|----------|----------|----------|
| **人脸识别** | 查寝打卡身份验证 | 百度AI人脸识别 / 腾讯云人脸核身 | OpenCV + FaceNet（教学加分项） |
| **活体检测** | 防照片/视频代签 | 百度AI活体检测 / 腾讯云意愿核身 | 动作序列检测：眨眼→点头→张嘴 |
| **定位验证** | 判断是否在电子围栏内 | 自研（Haversine公式算距） | — |
| **异常检测** | 代签行为识别 | 规则引擎 + 自研ML模型 | 基于行为的异常评分（时间、位置、设备等特征） |
| **OCR识别** | （可选）证件/票据识别用于请假 | 百度AI OCR | Tesseract OCR |

### 5.2 人脸识别技术方案

#### 5.2.1 流程设计

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  人脸注册     │     │  人脸打卡     │     │  活体检测     │     │  特征存储     │
│  (首次使用)   │     │  (每次打卡)   │     │  (打卡时)     │     │             │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
  采集3张不同角度    拍摄1张实时照片     要求做出随机动作     特征向量AES-256加密
  人脸图片          提取特征向量         动作序列匹配验证     存储至SQL Server
  提取特征向量base  与注册向量比对        通过则继续人脸比对    原始图片存MinIO
                   相似度 ≥ 85%判定通过                       7天后自动删除
```

#### 5.2.2 百度AI集成要点

```java
// 人脸注册接口
POST https://aip.baidubce.com/rest/2.0/face/v3/faceset/user/add
{
    "image": "<BASE64>",
    "image_type": "BASE64",
    "group_id": "dorm_checkin",
    "user_id": "<STUDENT_ID>",
    "quality_control": "HIGH",
    "liveness_control": "NONE"     // 注册时不需活体，拍照场景好
}

// 人脸搜索（打卡验证）
POST https://aip.baidubce.com/rest/2.0/face/v3/search
{
    "image": "<BASE64>",
    "image_type": "BASE64",
    "group_id": "dorm_checkin",
    "quality_control": "HIGH",
    "liveness_control": "HIGH",    // 打卡时要求活体
    "max_user_num": 1
}
// 响应：{ "user_id": "...", "score": 92.5, ... }
// score ≥ 85 → 验证通过
```

#### 5.2.3 人脸注册规范

| 要求 | 说明 |
|------|------|
| 注册照片数量 | ≥ 3张不同角度（正面、微左、微右） |
| 照片质量 | 分辨率 ≥ 640×480；光照均匀；无遮挡（墨镜、口罩） |
| 特征存储 | 提取的特征向量在百度云端存储；本地只存user_id映射 |
| 更新策略 | 每学期开学第1周重新注册（考虑发型/外貌变化） |
| 隐私保护 | 原始照片加密存储，7天后删除；特征向量不可逆 |

#### 5.2.4 自研备选方案（加分项）

对于有深度学习基础的小组，可加分实现：

- **框架**：TensorFlow Lite / MediaPipe（移动端推理）；PyTorch（服务端）
- **模型**：MobileFaceNet（轻量级，适合移动端）；FaceNet/ArcFace（服务端）
- **活体检测**：基于CNN的静默活体检测（Silent Face Anti-spoofing）
- **训练数据**：CASIA-FASD / CelebA-Spoof 开源数据集
- **推理方式**：移动端本地推理（保护隐私，无需上传原始照片）

### 5.3 定位验证算法

```
算法：Haversine 公式计算两点球面距离

给定：
  打卡点P(lat1, lon1) — 学生当前位置
  围栏中心F(lat2, lon2) — 预定打卡位置
  允许半径R — 如300米

计算：
  d = 2 × R_earth × arcsin(√(hav(Δlat) + cos(lat1)·cos(lat2)·hav(Δlon)))
  
判定：
  d ≤ R → 在围栏内，通过
  d > R → 超出范围，拒绝并提示距离
```

```java
// Java实现参考
public class GeoUtils {
    private static final double EARTH_RADIUS = 6371000; // 米
    
    public static double haversineDistance(double lat1, double lon1, 
                                           double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS * c;
    }
    
    public static boolean isWithinFence(double userLat, double userLon,
                                        double fenceLat, double fenceLon,
                                        double radiusMeters) {
        return haversineDistance(userLat, userLon, fenceLat, fenceLon) <= radiusMeters;
    }
}
```

### 5.4 异常检测设计

#### 5.4.1 规则引擎（Phase 1 — MVP必须）

| 规则ID | 规则描述 | 触发条件 |
|--------|----------|----------|
| R01 | 同一设备多账号 | 1台设备24h内登录 ≥ 3个不同账号 |
| R02 | 异常时段打卡 | 非打卡时段（如凌晨3点）的打卡请求 |
| R03 | 位置跳跃 | 前后两次打卡距离 > 500km 且时间差 < 2h |
| R04 | 快速打卡 | 同一账号两次打卡间隔 < 10秒 |
| R05 | 位置精确一致 | 多次打卡经纬度小数点后6位完全一致（可能是模拟定位） |

#### 5.4.2 ML异常评分（Phase 2 — 加分项）

```
特征工程（用于训练异常评分模型）：
  - 打卡时间偏差（相对历史均值）
  - 定位精度变化（GPS精度字段）
  - 设备更换频率
  - 人脸相似度得分
  - 动作完成时间（活体检测耗时）
  - 网络环境变化（IP段、WiFi名称）

模型选择：
  - 孤立森林 (Isolation Forest) — 无监督，适合冷启动
  - 或 LightGBM 分类器（需标注部分异常样本）
```

---

## 6. 数据库设计

### 6.1 ER图（核心实体关系）

```
┌──────────┐       ┌──────────────┐       ┌──────────────┐
│   User   │───1:N──│   Checkin    │───N:1──│  CheckinSite │
│  (用户)   │       │   (打卡记录)  │       │  (打卡点)     │
└────┬─────┘       └──────────────┘       └──────────────┘
     │
     ├──1:N──┌──────────┐
     │       │ LeaveReq  │
     │       │ (请假申请) │
     │       └──────────┘
     │
     ├──1:N──┌──────────┐
     │       │ InternLog │
     │       │ (实习日志) │
     │       └──────────┘
     │
     └──N:1──┌──────────┐
             │  Class    │
             │ (班级)     │
             └──────────┘
```

### 6.2 核心表结构（SQL Server）

> **SQL Server 语法说明**：
> - 自增主键使用 `BIGINT IDENTITY(1,1) PRIMARY KEY`
> - 布尔类型使用 `BIT`（0/1）
> - 默认时间使用 `DATETIME2 DEFAULT GETDATE()`
> - 大文本使用 `NVARCHAR(MAX)` 替代 `TEXT`
> - JSON字段使用 `NVARCHAR(MAX)` 存储，配合 `ISJSON()` 校验
> - 字符集统一使用 `NVARCHAR` 系列（Unicode，对应MySQL utf8mb4）

#### 6.2.1 用户表 (sys_user)

```sql
CREATE TABLE sys_user (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    student_id      NVARCHAR(20)  NOT NULL,
    real_name       NVARCHAR(50)  NOT NULL,
    password_hash   NVARCHAR(128) NOT NULL,
    role            NVARCHAR(20)  NOT NULL,          -- STUDENT / INSTRUCTOR / ADMIN
    class_id        BIGINT        NULL,
    phone           NVARCHAR(20)  NULL,
    face_registered BIT           DEFAULT 0,         -- 0:未注册 1:已注册
    face_group_id   NVARCHAR(50)  NULL,
    status          NVARCHAR(10)  DEFAULT 'ACTIVE',  -- ACTIVE / SUSPENDED / GRADUATED
    created_at      DATETIME2     DEFAULT GETDATE(),
    updated_at      DATETIME2     DEFAULT GETDATE(),
    CONSTRAINT uq_student_id UNIQUE (student_id)
);
CREATE INDEX idx_user_class ON sys_user(class_id);
CREATE INDEX idx_user_role_status ON sys_user(role, status);

-- 密码哈希注释：使用BCrypt (cost=12)加密
-- 更新时间通过触发器或应用层维护
```

#### 6.2.2 打卡点表 (checkin_site)

```sql
CREATE TABLE checkin_site (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    site_name       NVARCHAR(100) NOT NULL,
    site_type       NVARCHAR(20)  NOT NULL,          -- DORM / CLASSROOM / INTERNSHIP
    latitude        DECIMAL(10,7) NOT NULL,
    longitude       DECIMAL(10,7) NOT NULL,
    radius_meters   INT           DEFAULT 300,
    detail_address  NVARCHAR(255) NULL,
    status          NVARCHAR(10)  DEFAULT 'ACTIVE',
    created_at      DATETIME2     DEFAULT GETDATE()
);
CREATE INDEX idx_site_type_status ON checkin_site(site_type, status);
```

#### 6.2.3 打卡记录表 (checkin_record)

```sql
CREATE TABLE checkin_record (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id         BIGINT        NOT NULL,
    site_id         BIGINT        NOT NULL,
    checkin_type    NVARCHAR(20)  NOT NULL,          -- DORM / CLASS / INTERNSHIP
    checkin_time    DATETIME2     NOT NULL,
    latitude        DECIMAL(10,7) NULL,
    longitude       DECIMAL(10,7) NULL,
    face_score      DECIMAL(5,2)  NULL,
    face_passed     BIT           NULL,              -- 0:未通过 1:通过
    location_passed BIT           NULL,
    liveness_passed BIT           NULL,
    status          NVARCHAR(20)  DEFAULT 'SUCCESS', -- SUCCESS / FAILED / APPEALED
    device_info     NVARCHAR(255) NULL,
    ip_address      NVARCHAR(45)  NULL,
    fail_reason     NVARCHAR(100) NULL,
    created_at      DATETIME2     DEFAULT GETDATE(),
    CONSTRAINT fk_checkin_user FOREIGN KEY (user_id) REFERENCES sys_user(id),
    CONSTRAINT fk_checkin_site FOREIGN KEY (site_id) REFERENCES checkin_site(id)
);
CREATE INDEX idx_ck_user_time ON checkin_record(user_id, checkin_time);
CREATE INDEX idx_ck_site_time ON checkin_record(site_id, checkin_time);
CREATE INDEX idx_ck_type_date ON checkin_record(checkin_type, checkin_time);
CREATE INDEX idx_ck_status ON checkin_record(status);

-- 按月分区（SQL Server支持表分区）
-- 生产环境建议按 checkin_time 字段做范围分区
```

#### 6.2.4 实习日志表 (intern_log)

```sql
CREATE TABLE intern_log (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id         BIGINT        NOT NULL,
    company_name    NVARCHAR(100) NOT NULL,
    work_date       DATE          NOT NULL,
    content         NVARCHAR(MAX) NOT NULL,          -- 日志内容(50-300字)
    mentor_review   NVARCHAR(MAX) NULL,              -- 企业导师评阅
    mentor_id       BIGINT        NULL,
    created_at      DATETIME2     DEFAULT GETDATE(),
    CONSTRAINT uq_user_date UNIQUE (user_id, work_date),
    CONSTRAINT fk_internlog_user FOREIGN KEY (user_id) REFERENCES sys_user(id)
);
CREATE INDEX idx_intern_company ON intern_log(company_name);
```

#### 6.2.5 请假申请表 (leave_request)

```sql
CREATE TABLE leave_request (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id         BIGINT        NOT NULL,
    leave_type      NVARCHAR(20)  NOT NULL,          -- SICK / PERSONAL / ACADEMIC
    start_time      DATETIME2     NOT NULL,
    end_time        DATETIME2     NOT NULL,
    reason          NVARCHAR(MAX) NOT NULL,
    attachment_url  NVARCHAR(255) NULL,
    status          NVARCHAR(20)  DEFAULT 'PENDING', -- PENDING / APPROVED / REJECTED
    reviewer_id     BIGINT        NULL,
    review_comment  NVARCHAR(MAX) NULL,
    reviewed_at     DATETIME2     NULL,
    created_at      DATETIME2     DEFAULT GETDATE(),
    CONSTRAINT fk_leave_user FOREIGN KEY (user_id) REFERENCES sys_user(id)
);
CREATE INDEX idx_leave_user_status ON leave_request(user_id, status);
CREATE INDEX idx_leave_reviewer ON leave_request(reviewer_id, status);
```

#### 6.2.6 通知/预警表 (notification)

```sql
CREATE TABLE notification (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    receiver_id     BIGINT        NOT NULL,
    sender_id       BIGINT        NULL,
    notify_type     NVARCHAR(30)  NOT NULL,          -- REMINDER / WARNING / INFO / APPROVAL
    title           NVARCHAR(100) NOT NULL,
    content         NVARCHAR(MAX) NOT NULL,
    related_type    NVARCHAR(20)  NULL,              -- DORM / CLASS / INTERNSHIP
    related_id      BIGINT        NULL,
    is_read         BIT           DEFAULT 0,
    read_at         DATETIME2     NULL,
    created_at      DATETIME2     DEFAULT GETDATE()
);
CREATE INDEX idx_notify_receiver ON notification(receiver_id, is_read, created_at);
```

#### 6.2.7 操作审计表 (audit_log)

```sql
CREATE TABLE audit_log (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id         BIGINT        NULL,
    action          NVARCHAR(50)  NOT NULL,
    resource        NVARCHAR(50)  NOT NULL,
    resource_id     BIGINT        NULL,
    detail          NVARCHAR(MAX) NULL,              -- JSON格式 (SQL Server 支持 ISJSON 校验)
    ip_address      NVARCHAR(45)  NULL,
    user_agent      NVARCHAR(255) NULL,
    created_at      DATETIME2     DEFAULT GETDATE()
);
CREATE INDEX idx_audit_user_action ON audit_log(user_id, action, created_at);
CREATE INDEX idx_audit_created ON audit_log(created_at);
```

### 6.3 数据库规范

- **字符集**：NVARCHAR 系列（Unicode，天然支持中文/emoji，对应原MySQL utf8mb4）
- **存储引擎**：SQL Server 默认引擎（事务支持）
- **索引策略**：联合索引覆盖高频查询；定期通过 `sys.dm_db_index_usage_stats` 分析慢查询优化
- **分表策略**：`checkin_record` 表按月分区（预计单月数据量10万+条），使用 SQL Server 分区表功能
- **数据归档**：超过2年的打卡记录迁移到归档表，SQL Server 支持分区切换 (SWITCH) 实现快速归档
- **备份策略**：使用 SQL Server Agent 定时 FULL + DIFF + LOG 备份

---

## 7. API接口设计

### 7.1 RESTful API设计规范

```
基础路径：https://api.nhu-aisizheng.cn/api/v1

统一响应格式：
{
    "code": 200,            // HTTP状态码
    "message": "success",   // 提示信息
    "data": { ... },        // 业务数据
    "timestamp": 1719417600 // Unix时间戳
}

错误响应格式：
{
    "code": 400,
    "message": "打卡时间不在有效时段内",
    "data": null,
    "timestamp": 1719417600
}
```

### 7.2 核心API清单

#### 7.2.1 认证模块

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/auth/login` | 账号密码登录 → JWT Token |
| POST | `/auth/refresh` | 刷新Token |
| POST | `/auth/logout` | 登出（Token加入黑名单） |
| POST | `/auth/face-register` | 首次人脸注册（上传3张照片） |

#### 7.2.2 打卡模块

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/checkin/dorm` | 查寝打卡（body: 经纬度 + 人脸照片BASE64） |
| POST | `/checkin/class` | 上课打卡（body: 经纬度 或 扫码数据） |
| POST | `/checkin/intern` | 实习打卡（body: 经纬度 + 日志内容） |
| GET  | `/checkin/status/today` | 查询今日各类型打卡状态 |
| GET  | `/checkin/history` | 查询个人打卡历史（分页） |
| POST | `/checkin/{id}/appeal` | 对异常记录发起申诉 |

#### 7.2.3 管理模块（辅导员/教师端）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET  | `/manage/class/{id}/dorm-today` | 班级今日查寝汇总 |
| GET  | `/manage/class/{id}/attendance` | 班级课程出勤统计 |
| GET  | `/manage/intern/monitor` | 实习打卡监控列表 |
| GET  | `/manage/alerts` | 当前预警列表（分页） |
| POST | `/manage/appeal/{id}/review` | 审批申诉 |
| GET  | `/manage/report/weekly` | 生成周报 |
| GET  | `/manage/report/export` | 导出考勤报表(Excel) |

#### 7.2.4 实习日志模块

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/intern/log` | 提交实习日志 |
| GET  | `/intern/log/history` | 查询个人日志历史 |
| POST | `/intern/log/{id}/review` | 企业导师评阅 |
| GET  | `/intern/archive/{userId}` | 生成实习档案 |

#### 7.2.5 请假模块

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/leave/apply` | 提交请假申请 |
| GET  | `/leave/list` | 个人请假记录 |
| POST | `/leave/{id}/approve` | 审批请假（辅导员） |
| POST | `/leave/{id}/reject` | 驳回请假（辅导员） |

### 7.3 接口安全规范

- **鉴权**：除 `/auth/login` 外所有接口需携带 `Authorization: Bearer <JWT>`
- **签名**：打卡类接口增加请求签名（时间戳 + 随机数 + 签名，防重放）
- **加密**：人脸图片传输使用 RSA+AES 混合加密（客户端RSA公钥加密AES密钥，AES加密图片数据）
- **脱敏**：接口响应中手机号、详细地址等字段脱敏

---

## 8. 安全技术方案

### 8.1 数据安全

| 安全措施 | 实现方案 |
|----------|----------|
| 传输加密 | 全站HTTPS (TLS 1.3)；证书通过Let's Encrypt或学校CA签发 |
| 人脸数据加密 | AES-256-GCM 加密人脸图片存储；特征向量加盐哈希 |
| 密码存储 | BCrypt (cost=12) 哈希 |
| 数据库加密 | 敏感字段应用层AES加密（学号、手机号等） |
| 备份加密 | 数据库备份文件GPG加密后存储 |

### 8.2 应用安全

| 安全措施 | 实现方案 |
|----------|----------|
| SQL注入防护 | MyBatis参数化查询 + 输入校验 |
| XSS防护 | 输出编码 + CSP头；管理端对所有用户输入做HTML转义 |
| CSRF防护 | JWT + SameSite Cookie；管理端额外使用CSRF Token |
| 文件上传安全 | 文件类型白名单（仅允许jpg/png/pdf）；大小限制5MB；病毒扫描（可选） |
| 接口限流 | Nginx + Redis滑动窗口；打卡接口 10次/分钟/用户 |
| 防刷 | 图形验证码（登录3次失败后触发）；同一设备打卡间隔 ≥ 10秒 |

### 8.3 移动端安全

| 安全措施 | 实现方案 |
|----------|----------|
| 代码混淆 | Flutter代码混淆 (`--obfuscate`)；ProGuard/R8 |
| 反调试 | Flutter release模式；检测模拟器/ROOT设备 |
| 安全存储 | `flutter_secure_storage` (KeyChain/iOS Keystore) |
| 证书固定 | SSL Pinning（固定服务端证书指纹） |
| 模拟定位检测 | 检测是否开启了开发者选项中的"模拟位置" |

### 8.4 运维安全

| 安全措施 | 实现方案 |
|----------|----------|
| 访问控制 | 服务器仅开放80/443端口；SSH密钥登录+IP白名单 |
| 日志审计 | 所有管理操作记录audit_log表；ELK集中分析 |
| 异常告警 | 连续登录失败、异地登录、批量数据导出触发告警 |
| 漏洞管理 | 依赖安全扫描（Snyk/Dependabot）；定期OS安全补丁 |

---

## 9. 部署与运维

### 9.1 部署架构

```
┌─────────────────────────────────────────────────────────┐
│                    负载均衡 (Nginx) ×2                    │
│                  keepalived 高可用VIP                     │
└──────────────┬──────────────────────┬───────────────────┘
               │                      │
               ▼                      ▼
┌──────────────────────┐  ┌──────────────────────┐
│  应用服务器 1         │  │  应用服务器 2         │
│  Spring Boot App     │  │  Spring Boot App     │
│  (Docker Container)  │  │  (Docker Container)  │
└──────────┬───────────┘  └──────────┬───────────┘
           │                         │
           └─────────┬───────────────┘
                     │
      ┌──────────────┼──────────────┐
      │              │              │
      ▼              ▼              ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│SQL Server│  │  Redis   │  │  MinIO   │
│  本机实例  │  │  哨兵模式 │  │  单节点   │
└──────────┘  └──────────┘  └──────────┘
```

### 9.2 部署方案

#### 方案一：学校自有服务器（推荐）

```
资源需求：
├── 应用服务器：2台 (4C8G, 100G SSD)
├── 数据库服务器：SQL Server 本机实例 (Developer版免费) — 使用学校已有SQL Server
├── 对象存储：MinIO部署在应用服务器或独立节点
└── 域名+SSL证书：通过学校信息中心申请
```

#### 方案二：云服务器（备选）

- 阿里云 / 腾讯云 ECS + RDS + OSS
- 学生优惠 / 教育优惠套餐
- 预估月成本：¥300-800（试点期，根据用户量调整）

### 9.3 Docker容器化

```yaml
# docker-compose.yml (开发环境)
# SQL Server 使用本机安装实例（不在Docker中运行）
# 此文件仅管理辅助服务
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    container_name: ai_sizheng_redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

  minio:
    image: minio/minio
    container_name: ai_sizheng_minio
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"    # API端口
      - "9001:9001"    # 控制台端口
    volumes:
      - minio_data:/data
    environment:
      MINIO_ROOT_USER: admin
      MINIO_ROOT_PASSWORD: admin123456
    restart: unless-stopped

volumes:
  redis_data:
  minio_data:
```

> **注意**：SQL Server 使用 Windows 本机安装的实例（默认 `localhost`），无需放在 Docker 中。连接信息见 `application-dev.yml`。

### 9.4 CI/CD流水线

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Git Push │───→│  Build   │───→│  Test    │───→│  Deploy  │
│  (Gitee)  │    │  Maven   │    │  JUnit   │    │  Docker  │
│           │    │  Flutter │    │  Widget  │    │  Compose │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
```

- **代码仓库**：Gitee（私有仓库，小组各自管理）
- **CI工具**：Gitee CI / GitHub Actions / Jenkins（学校服务器）
- **制品管理**：Docker Registry (校内)
- **自动部署**：Docker Compose + Watchtower（自动拉取新镜像）

---

## 10. 测试策略

### 10.1 测试层次

| 测试类型 | 覆盖率目标 | 工具 | 说明 |
|----------|-----------|------|------|
| **单元测试** | ≥ 60% | JUnit 5 + Mockito | Service层核心逻辑 |
| **接口测试** | ≥ 80% 核心接口 | Postman / REST Assured | API功能正确性 |
| **Widget测试** | 关键页面全覆盖 | Flutter Test | 打卡页、登录页 |
| **集成测试** | 全流程 | Postman Collection | 端到端业务流程 |
| **性能测试** | 500并发 | JMeter | 查寝高峰期压测 |
| **安全测试** | OWASP Top 10 | 人工检查 | 渗透测试要点 |

### 10.2 测试重点

| 场景 | 测试用例示例 |
|------|------------|
| 正常打卡 | GPS在围栏内+人脸匹配≥85% → 打卡成功 |
| 位置越界 | GPS在围栏外 → 提示"不在打卡范围内" |
| 人脸不匹配 | 他人代打 → 提示"面部验证失败" |
| 活体攻击 | 照片/视频攻击 → 活体检测拦截 |
| 重复打卡 | 同一时段第二次打卡 → 提示"今日已打卡" |
| 代签检测 | 同设备登录3个不同账号打卡 → 标记异常 |
| 离线打卡 | 断网下完成实习打卡 → 联网后自动同步 |
| 并发压力 | 500人同时查寝打卡 → 成功率 ≥ 99% |
| 弱网环境 | 2G/3G网络下 → 打卡超时提示，支持重试 |

### 10.3 用户验收测试（UAT）

- 校内导师（辅导员）：验证管理功能是否符合实际工作流程
- 试点学生群体：验证打卡体验是否流畅、是否有漏洞
- 企业导师：验证代码质量与架构合理性

---

## 11. 开发规范与工具链

### 11.1 代码规范

| 语言/框架 | 规范 | 检查工具 |
|-----------|------|----------|
| Java | 阿里巴巴Java开发手册 | IDEA插件 + Checkstyle |
| Dart/Flutter | Effective Dart | `flutter analyze` |
| JavaScript/React | Airbnb JS Style Guide | ESLint + Prettier |
| SQL | 关键字大写 + 命名规范 | 人工Code Review |

### 11.2 Git工作流

```
main (生产分支)
  └── develop (开发分支)
        ├── feature/dorm-checkin    (查寝打卡功能)
        ├── feature/class-checkin   (上课打卡功能)
        ├── feature/intern-checkin  (实习打卡功能)
        ├── feature/admin-web       (管理后台)
        └── fix/xxx                 (Bug修复分支)
```

**规范**：
- 分支命名：`feature/<功能>` / `fix/<问题>` / `docs/<文档>`
- Commit规范：`<type>(<scope>): <subject>`（如：`feat(checkin): 实现GPS定位验证`）
- Code Review：至少1名组员Review后合并
- 禁止直接push到main/develop分支

### 11.3 协作工具

| 工具类型 | 推荐工具 | 说明 |
|----------|----------|------|
| 项目管理 | 飞书多维表格 / 腾讯文档 | 需求跟踪、Bug管理、周报 |
| 代码托管 | Gitee（私有仓库） | 每组独立仓库 |
| API管理 | Apifox / Postman | API设计与测试 |
| 原型设计 | Figma / 墨刀 | UI设计稿 |
| 文档协作 | 腾讯文档 / Notion | PRD/TRD/会议纪要 |
| 即时通讯 | 微信群 / 飞书群 | 日常沟通 |
| CI/CD | Gitee CI / Jenkins | 自动构建 |

---

## 12. 附录

### 附录A：关键依赖清单（许可证检查）

| 依赖 | 许可证 | 商用风险 |
|------|--------|----------|
| Flutter | BSD-3-Clause | ✅ 无风险 |
| Spring Boot | Apache 2.0 | ✅ 无风险 |
| SQL Server Developer | 免费（开发/测试） | ✅ 教育用途免费 |
| Redis | BSD-3-Clause | ✅ 无风险 |
| MinIO | AGPL v3 | ⚠️ 仅使用API/SDK（Apache 2.0），不修改MinIO源码 |
| RabbitMQ | MPL 2.0 | ✅ 无风险 |
| 百度AI SDK | Apache 2.0 | ✅ 无风险（注意API调用额度） |
| ECharts | Apache 2.0 | ✅ 无风险 |
| Ant Design | MIT | ✅ 无风险 |

### 附录B：百度AI人脸识别免费额度

| 接口 | 免费额度 | 说明 |
|------|----------|------|
| 人脸检测 | 无限次（QPS=2） | 基本够用 |
| 人脸比对 | 无限次（QPS=2） | 基本够用 |
| 人脸搜索 | 无限次（QPS=2） | 打卡高峰期可能需要提升QPS |
| 活体检测 | 无限次（QPS=2） | 够用 |

> 注：按500名学生 × 每日3次打卡 × 30天 = 45,000次/月。QPS=2表示每秒可处理2个请求，考虑峰值需申请临时提升QPS或使用队列削峰。

### 附录C：开发环境搭建指南（快速启动）

```bash
# 0. 前置条件
# - SQL Server 已在本机安装并运行（默认实例 localhost, Windows身份验证）
# - Docker Desktop 已启动
# - Java 17 + Maven 已配置

# 1. 创建数据库
sqlcmd -S localhost -E -Q "CREATE DATABASE ai_sizheng"
sqlcmd -S localhost -E -d ai_sizheng -i init_db.sql   # 执行建表脚本

# 2. 启动基础设施（Redis + MinIO）
docker-compose up -d

# 3. 后端
git clone <仓库地址>
cd backend
cp application-dev.yml.example application-dev.yml
# 修改SQL Server连接为: jdbc:sqlserver://localhost;databaseName=ai_sizheng;integratedSecurity=true
mvn spring-boot:run

# 4. 管理Web端
cd admin-web
npm install
npm run dev

# 5. 移动端
cd mobile
flutter pub get
flutter run
```

### 附录D：缩略语

| 缩略语 | 全称 |
|--------|------|
| PRD | Product Requirements Document |
| TRD | Technical Requirements Document |
| MVP | Minimum Viable Product |
| RBAC | Role-Based Access Control |
| JWT | JSON Web Token |
| QPS | Queries Per Second |
| RTO | Recovery Time Objective |
| RPO | Recovery Point Objective |
| CI/CD | Continuous Integration / Continuous Deployment |

---

> **文档审批**
>
> | 角色 | 签字/日期 |
> |------|-----------|
> | 技术负责人（企业导师代表） | |
> | 校内导师代表 | |
> | 学院审批 | |
>
> ---
>
> **修订历史**
>
> | 版本 | 日期 | 修订内容 | 修订人 |
> |------|------|----------|--------|
> | V1.0 | 2026-06-26 | 初始版本 | — |
