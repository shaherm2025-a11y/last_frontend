import 'dart:html' as html;
import 'package:uuid/uuid.dart';

Future<String> getDeviceId() async {
  const key = 'web_device_id';
  String? id = html.window.localStorage[key];

  if (id == null) {
    id = const Uuid().v4();
    html.window.localStorage[key] = id;
  }

  return id;
}
