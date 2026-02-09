import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final api = ApiService(baseUrl: 'http://10.0.2.2:8000/api/');

  void _register() async {
    final res = await api.post('accounts/register/', {
      'username': _userCtrl.text,
      'email': _emailCtrl.text,
      'password': _passCtrl.text
    });
    if (res.statusCode == 201) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Register')),
        body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                  controller: _userCtrl,
                  decoration: InputDecoration(labelText: 'Username')),
              TextField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(labelText: 'Email')),
              TextField(
                  controller: _passCtrl,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true),
              SizedBox(height: 12),
              ElevatedButton(onPressed: _register, child: Text('Register'))
            ])));
  }
}
