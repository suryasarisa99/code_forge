import 'package:code_forge/AI_completion/ai.dart';
import 'package:code_forge/LSP/lsp.dart';
import 'package:code_forge/code_forge.dart';
import 'package:example/big_code.dart';
import 'package:example/little_code.dart';
import 'package:example/small_code.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:re_highlight/languages/dart.dart';

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
          filePath: "/home/athul/Projects/EhEh/sample.py",
          controller: _controller,
          textStyle: GoogleFonts.jetBrainsMono(),
          aiCompletion: AiCompletion(
            model: Gemini(
              apiKey: "AIzaSyB-1JwovLrD9CJoZtEj5ZS43YJ7z7fAl9Q"
            )
          ),
          lspConfig: LspSocketConfig(
            filePath: "/home/athul/Projects/EhEh/sample.py",
            languageId: "python",
            serverUrl: "ws://0.0.0.0:3031",
            workspacePath: "/home/athul/Projects/EhEh",
          ),
          gutterStyle: GutterStyle(
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
