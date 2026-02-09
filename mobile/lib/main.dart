import 'package:flutter/material.dart';
import 'routes.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'DigitalPress',
        theme: ThemeData(primarySwatch: Colors.blue),
        initialRoute: '/',
        routes: appRoutes,
      ),
    );
  }
}
