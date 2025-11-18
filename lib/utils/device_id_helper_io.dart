import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

Future<String> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  const key = 'device_id';

  // إذا كان هناك معرف مخزن مسبقًا نعيده
  String? id = prefs.getString(key);
  if (id != null) return id;

  String newId;
  final info = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final android = await info.androidInfo;
    newId = android.id ?? const Uuid().v4();
  } else if (Platform.isIOS) {
    final ios = await info.iosInfo;
    newId = ios.identifierForVendor ?? const Uuid().v4();
  } else if (Platform.isWindows) {
    final win = await info.windowsInfo;
    newId = win.deviceId ?? const Uuid().v4();
  } else {
    newId = const Uuid().v4();
  }

  // نحفظ المعرف للاستخدام لاحقًا
  await prefs.setString(key, newId);
  return newId;
}
