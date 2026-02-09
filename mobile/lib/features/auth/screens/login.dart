import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final api = ApiService(baseUrl: 'http://10.0.2.2:8000/api/');

  void _login() async {
    final res = await api.post('accounts/login/',
        {'username': _userCtrl.text, 'password': _passCtrl.text});
    if (res.statusCode == 200) {
      final body = res.body;
      final token =
          RegExp('"access"\s*:\s*"([^"]+)"').firstMatch(body)?.group(1);
      if (token != null) {
        Provider.of<AuthProvider>(context, listen: false).setToken(token);
        Navigator.pushReplacementNamed(context, '/reader');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Login')),
        body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                  controller: _userCtrl,
                  decoration: InputDecoration(labelText: 'Username')),
              TextField(
                  controller: _passCtrl,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true),
              SizedBox(height: 12),
              ElevatedButton(onPressed: _login, child: Text('Login')),
              TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: Text('Register'))
            ])));
  }
}
