import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/lesson.dart';
import 'package:app/constants/colors.dart';
import 'pages/home.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Hive
  await Hive.initFlutter((await getApplicationDocumentsDirectory()).path);

  // تسجيل الـ Adapter
  Hive.registerAdapter(LessonAdapter());

  // فتح الصناديق (Boxes)
  await Hive.openLazyBox<Lesson>('lessons');        // LazyBox مهم للبيانات الكبيرة
  await Hive.openBox('settings');                   // للإعدادات العامة


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
        fontFamily: 'Cairo', // Recommended Arabic-friendly font (add to pubspec.yaml)
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.accent, // Teal accent
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