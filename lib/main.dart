import 'package:flutter/material.dart';
import 'app.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Use GoogleFonts Poppins if local fonts not set up
    return MaterialApp(
      title: 'Tryb Ludo UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: Color(0xFF0F1218),
      ),
      home: AppShell(),
    );
  }
}
