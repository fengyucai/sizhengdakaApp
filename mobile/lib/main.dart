import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const AiSizhengApp());
}

class AiSizhengApp extends StatefulWidget {
  const AiSizhengApp({super.key});

  @override
  State<AiSizhengApp> createState() => _AiSizhengAppState();
}

class _AiSizhengAppState extends State<AiSizhengApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _authService.init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
      ],
      child: MaterialApp.router(
        title: 'AI思政打卡',
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  final AuthService _authService = AuthService();
}
