import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'blocs/auth/auth_bloc.dart';
import 'screens/activation_setup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),
        ProxyProvider<ApiClient, AuthService>(
          update: (_, apiClient, _) => AuthService(apiClient),
        ),
      ],
      child: Builder(
        builder: (context) => BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(context.read<AuthService>()),
          child: MaterialApp(
            title: 'Store Buddy POS',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            home: const StartupGate(),
          ),
        ),
      ),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  Future<bool>? _hasStoreLoginsFuture;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(AuthCheckStatusRequested());
    _hasStoreLoginsFuture = context.read<AuthService>().hasAnyStoreLogins();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasStoreLoginsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final hasStoreLogins = snapshot.data ?? false;
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (state is AuthAuthenticated) {
              return const DashboardScreen();
            }

            if (!hasStoreLogins) {
              return const ActivationSetupScreen();
            }

            return const LoginScreen();
          },
        );
      },
    );
  }
}
