import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'blocs/auth/auth_bloc.dart';
import 'screens/activation_setup_screen.dart';
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

class StartupGate extends StatelessWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return FutureBuilder<bool>(
      future: authService.hasAnyStoreLogins(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasStoreLogins = snapshot.data ?? false;
        if (!hasStoreLogins) {
          return const ActivationSetupScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
