import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/lesson.dart';
import 'constants/colors.dart';
import 'pages/home.dart';
import 'services/lesson_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Hive using the app documents directory.
  final appDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDir.path);

  // Register generated type adapters.
  Hive.registerAdapter(LessonAdapter());

  // Open boxes.
  await Hive.openLazyBox<Lesson>('lessons');
  await Hive.openBox('settings'); // Track general user activity/settings

  // Seed / sync lessons from the remote curriculum.
  await LessonService().initializeLessons();

  // Initialize daily reminder notification service.
  await NotificationService().init();

  runApp(const MafazaApp());
}

class MafazaApp extends StatelessWidget {
  const MafazaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مفازا | إعادة إحياء أمة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.darkOne,
        fontFamily: 'Cairo',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkOne,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
