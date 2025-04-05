import 'package:flutter/material.dart';

class EditRolesScreen extends StatelessWidget {
  const EditRolesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D162D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2157),
        title: const Text('Редактировать роли', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              keyboardType: TextInputType.text,  // Разрешает ввод текста
              decoration: const InputDecoration(
                labelText: 'Спикер 1',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Color(0xFF1A2157),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.text,  // Разрешает ввод текста
              decoration: const InputDecoration(
                labelText: 'Спикер 2',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Color(0xFF1A2157),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
