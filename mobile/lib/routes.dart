import 'package:flutter/material.dart';
import 'features/auth/screens/login.dart';
import 'features/auth/screens/register.dart';
import 'features/reader/screens/home.dart';
import 'features/reader/screens/detail.dart';
import 'features/publisher/screens/dashboard.dart';
import 'features/admin/screens/panel.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => LoginScreen(),
  '/register': (context) => RegisterScreen(),
  '/reader': (context) => ReaderHomeScreen(),
  '/publication': (context) => PublicationDetailScreen(),
  '/publisher': (context) => PublisherDashboard(),
  '/admin': (context) => AdminPanel(),
};
