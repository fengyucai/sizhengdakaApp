import 'package:go_router/go_router.dart';
import '../pages/login/login_page.dart';
import '../pages/home/home_page.dart';
import '../pages/checkin_dorm/dorm_checkin_page.dart';
import '../pages/checkin_class/class_checkin_page.dart';
import '../pages/checkin_class/class_qr_scan_page.dart';
import '../pages/checkin_intern/intern_checkin_page.dart';
import '../pages/face/face_register_page.dart';
import '../pages/leave/leave_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/profile/change_password_page.dart';
import '../pages/profile/attendance_stats_page.dart';
import '../pages/profile/settings_page.dart';
import '../pages/profile/about_page.dart';
import '../pages/profile/privacy_consent_page.dart';
import '../pages/message/message_page.dart';
import '../pages/records/checkin_records_page.dart';
import '../pages/teacher/teacher_home_page.dart';
import '../pages/teacher/teacher_leave_approval_page.dart';
import '../pages/teacher/teacher_appeal_review_page.dart';
import '../pages/teacher/teacher_intern_logs_page.dart';
import '../pages/teacher/teacher_students_page.dart';
import '../pages/teacher/teacher_dorm_locations_page.dart';
import '../pages/teacher/teacher_class_workbench_page.dart';
import '../pages/teacher/teacher_alerts_page.dart';
import '../pages/teacher/teacher_sites_page.dart';
import '../pages/teacher/teacher_reports_page.dart';
import '../pages/teacher/teacher_audit_logs_page.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
          path: '/privacy/consent',
          builder: (_, __) => const PrivacyConsentPage()),
      GoRoute(
          path: '/privacy/review',
          builder: (_, __) => const PrivacyConsentPage(reviewOnly: true)),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      GoRoute(
          path: '/checkin/dorm', builder: (_, __) => const DormCheckinPage()),
      GoRoute(
          path: '/checkin/class', builder: (_, __) => const ClassCheckinPage()),
      GoRoute(
          path: '/checkin/class/scan',
          builder: (_, __) => const ClassQrScanPage()),
      GoRoute(
          path: '/checkin/intern',
          builder: (_, __) => const InternCheckinPage()),
      GoRoute(
          path: '/face/register', builder: (_, __) => const FaceRegisterPage()),
      GoRoute(path: '/leave', builder: (_, __) => const LeavePage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(
          path: '/password/change',
          builder: (_, __) => const ChangePasswordPage()),
      GoRoute(
          path: '/attendance', builder: (_, __) => const AttendanceStatsPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/about', builder: (_, __) => const AboutPage()),
      GoRoute(path: '/messages', builder: (_, __) => const MessagePage()),
      GoRoute(path: '/records', builder: (_, __) => const CheckinRecordsPage()),
      GoRoute(
          path: '/teacher/home', builder: (_, __) => const TeacherHomePage()),
      GoRoute(
          path: '/teacher/leaves',
          builder: (_, __) => const TeacherLeaveApprovalPage()),
      GoRoute(
          path: '/teacher/appeals',
          builder: (_, __) => const TeacherAppealReviewPage()),
      GoRoute(
          path: '/teacher/intern-logs',
          builder: (_, __) => const TeacherInternLogsPage()),
      GoRoute(
          path: '/teacher/students',
          builder: (_, __) => const TeacherStudentsPage()),
      GoRoute(
          path: '/teacher/dorm-locations',
          builder: (_, __) => const TeacherDormLocationsPage()),
      GoRoute(
          path: '/teacher/class-workbench',
          builder: (_, __) => const TeacherClassWorkbenchPage()),
      GoRoute(
          path: '/teacher/alerts',
          builder: (_, __) => const TeacherAlertsPage()),
      GoRoute(
          path: '/teacher/sites', builder: (_, __) => const TeacherSitesPage()),
      GoRoute(
          path: '/teacher/reports',
          builder: (_, __) => const TeacherReportsPage()),
      GoRoute(
          path: '/teacher/audit-logs',
          builder: (_, __) => const TeacherAuditLogsPage()),
    ],
  );
}
