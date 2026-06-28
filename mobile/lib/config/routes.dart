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
import '../pages/message/message_page.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      GoRoute(path: '/checkin/dorm', builder: (_, __) => const DormCheckinPage()),
      GoRoute(path: '/checkin/class', builder: (_, __) => const ClassCheckinPage()),
      GoRoute(path: '/checkin/class/scan', builder: (_, __) => const ClassQrScanPage()),
      GoRoute(path: '/checkin/intern', builder: (_, __) => const InternCheckinPage()),
      GoRoute(path: '/face/register', builder: (_, __) => const FaceRegisterPage()),
      GoRoute(path: '/leave', builder: (_, __) => const LeavePage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(path: '/messages', builder: (_, __) => const MessagePage()),
    ],
  );
}
