import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:test/auth/auth.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'firebase_option.dart';

Future<void> main() async {
  Gemini.init(
    apiKey: 'AIzaSyBj2VLUb95TcjQU01sdTF6Zz0AvnMaCk1I', // API key của Gemini
  );
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Firebase',
      home: AuthScreen(),
    );
  }
}
