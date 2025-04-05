import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/conversation_list_screen.dart';
import 'screens/conversation_detail_screen.dart';
import 'screens/add_conversation_screen.dart';
import 'screens/edit_roles_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GigaSecretary',
      theme: ThemeData.dark(),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/list': (context) => const ConversationListScreen(),
        '/detail': (context) => ViewRecordingScreen(),
        '/add': (context) => const AddConversationScreen(),
        '/roles': (context) => const EditRolesScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
