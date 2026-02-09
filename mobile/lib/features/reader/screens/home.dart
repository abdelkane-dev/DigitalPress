import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'detail.dart';

class ReaderHomeScreen extends StatefulWidget {
  @override
  _ReaderHomeScreenState createState() => _ReaderHomeScreenState();
}

class _ReaderHomeScreenState extends State<ReaderHomeScreen> {
  final api = ApiService(baseUrl: 'http://10.0.2.2:8000/api/');
  List items = [];

  void load() async {
    final res = await api.get('publications/');
    if (res.statusCode == 200) {
      setState(() => items = res.body.isNotEmpty ? [] : []); // placeholder
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reader - Publications')),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, i) => ListTile(
            title: Text('Sample Publication #${i + 1}'),
            onTap: () => Navigator.pushNamed(context, '/publication')),
      ),
    );
  }
}
