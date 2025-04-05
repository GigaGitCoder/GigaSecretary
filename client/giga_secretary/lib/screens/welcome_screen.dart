import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E3254),
      body: Center(
        child: ElevatedButton(
          child: const Text('Войти в GigaSecretary'),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/list');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B47AE), // исправлено на backgroundColor
            foregroundColor: Colors.white, // исправлено на foregroundColor
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
