import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> clearSharedPreferences() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print("✅ تم مسح كل بيانات SharedPreferences");
  } catch (e) {
    print("❌ حدث خطأ أثناء مسح SharedPreferences: $e");
  }
}

// مثال على كيفية التنفيذ عند الحاجة
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await clearSharedPreferences();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text("SharedPreferences تم مسحها"),
        ),
      ),
    );
  }
}
