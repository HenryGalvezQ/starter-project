import 'package:flutter/material.dart';

class MyReports extends StatelessWidget {
  const MyReports({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Reports',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: const Center(
        child: Text('My Reports Work in Progress'),
      ),
    );
  }
}