import 'package:code_forge/code_area.dart';
import 'package:code_forge/controller.dart';
import 'package:example/little_code.dart';
import 'package:example/small_code.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _controller = CodeForgeController();

  @override
  void initState(){
    _controller.text = little_code;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SafeArea(
        child: CodeForge(
          controller: _controller,
        )
      ),
    );
  }
}
