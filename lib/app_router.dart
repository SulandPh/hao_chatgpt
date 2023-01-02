import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hao_chatgpt/src/page/chat_page.dart';
import 'package:hao_chatgpt/src/page/home_page.dart';
import 'package:hao_chatgpt/src/page/settings_page.dart';

class AppRouter {
  AppRouter._internal();
  static final AppRouter _appRouter = AppRouter._internal();
  factory AppRouter() => _appRouter;

  /// The route configuration.
  final GoRouter _goRouter = GoRouter(
    restorationScopeId: 'go_router',
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const HomePage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'settings',
            builder: (BuildContext context, GoRouterState state) => const SettingsPage(),
          ),
          GoRoute(
            path: 'chat_page',
            builder: (BuildContext context, GoRouterState state) => const ChatPage(),
          ),
        ],
      ),
    ],
  );

  GoRouter get goRouter => _goRouter;
}