import 'package:code_forge/code_forge.dart';
import 'package:example/big_code.dart';
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
    _controller.text = big_code;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SafeArea(
        child: CodeForge(
          controller: _controller,
          enableFolding: true,
          enableGuideLines: true,
          enableGutter: true,
          backgroundColor: const Color(0xFF1E1E1E),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: Color(0xFFD4D4D4),
          ),
          gutterStyle: const GutterStyle(
            backgroundColor: Color(0xFF252526),
            lineNumberStyle: TextStyle(
              color: Color(0xFF858585),
              fontSize: 12,
            ),
            foldedIconColor: Color(0xFFD4D4D4),
            unfoldedIconColor: Color(0xFF858585),
          ),
          selectionStyle: CodeSelectionStyle(
            cursorColor: const Color(0xFFAEAFAD),
            //TODO
            selectionColor: const Color(0xFF264F78).withOpacity(0.5),
          ),
        )
      ),
    );
  }
}
