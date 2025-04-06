import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'screens/welcome_screen.dart';
import 'screens/conversation_list_screen.dart';
import 'screens/conversation_detail_screen.dart';
import 'screens/add_conversation_screen.dart';
import 'screens/edit_roles_screen.dart';
import 'screens/settings_screen.dart';
import 'services/drive_service.dart';
import 'services/conversation_service.dart';
import 'models/conversation.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final googleSignIn = GoogleSignIn(
      scopes: [
        drive.DriveApi.driveFileScope,
      ],
    );

    final driveService = DriveService(googleSignIn);
    final conversationService = ConversationService(driveService);

    return MaterialApp(
      title: 'GigaSecretary',
      theme: ThemeData.dark(),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final args = settings.arguments as Map<String, dynamic>;
          final conversationId = args['id'] as String;
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<List<Conversation>>(
              future: conversationService.getConversations(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final conversation = snapshot.data!.firstWhere(
                    (c) => c.id == conversationId,
                    orElse: () => throw Exception('Запись не найдена'),
                  );
                  return ConversationDetailScreen(
                    conversation: conversation,
                    conversationService: conversationService,
                    driveService: driveService,
                  );
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Ошибка')),
                    body: Center(child: Text('Ошибка: ${snapshot.error}')),
                  );
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          );
        }
        return null;
      },
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/list': (context) => ConversationListScreen(
              driveService: driveService,
              conversationService: conversationService,
              googleSignIn: googleSignIn,
            ),
        '/add': (context) => AddConversationScreen(
              driveService: driveService,
              conversationService: conversationService,
            ),
        '/roles': (context) => const EditRolesScreen(),
        '/settings': (context) => SettingsScreen(
              googleSignIn: googleSignIn,
              driveService: driveService,
            ),
      },
    );
  }
}