import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';


class WeatherWidget extends StatefulWidget {
  const WeatherWidget({Key? key}) : super(key: key);

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  bool _loading = true;
  String _city = "";
  String _description = "";
  double _temp = 0.0;
  String _mainWeather = "";
  String _dateString = "";

  @override
  void initState() {
    super.initState();
    _getWeather();
  }

  Future<void> _getWeather() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _description = "خدمة الموقع غير مفعّلة");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _description = "تم رفض إذن الموقع");
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude;
      final lon = position.longitude;

      // ?? اللغة من إعدادات التطبيق
      final locale = Localizations.localeOf(context).languageCode;
      final langParam = locale == "ar" ? "ar" : "en";

      const apiKey = "e04da9dcf248d89ed0105343de3270bd";
      final url = Uri.parse(
        "https://api.openweathermap.org/data/2.5/weather"
        "?lat=$lat&lon=$lon&units=metric&lang=$langParam&appid=$apiKey",
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      final now = DateTime.now();
      final formatter = DateFormat('EEEE، d MMMM', locale == "ar" ? 'ar' : 'en');
      final dateStr = formatter.format(now);

      setState(() {
        _city = data["name"];
        _temp = data["main"]["temp"].toDouble();
        _description = data["weather"][0]["description"];
        _mainWeather = data["weather"][0]["main"];
        _dateString = dateStr;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _description = "تعذر جلب حالة الطقس";
        _loading = false;
      });
    }
  }

  // ?? تحديد اللون حسب حالة الطقس
  Color _backgroundColor() {
    switch (_mainWeather.toLowerCase()) {
      case "clear":
        return Colors.orangeAccent;
      case "clouds":
        return Colors.blueGrey;
      case "rain":
      case "drizzle":
        return Colors.indigo;
      case "thunderstorm":
        return Colors.deepPurple;
      case "snow":
        return Colors.lightBlueAccent;
      default:
        return Colors.teal;
    }
  }

  // ??? أيقونة الطقس
  IconData _weatherIcon() {
    switch (_mainWeather.toLowerCase()) {
      case "clear":
        return Icons.wb_sunny;
      case "clouds":
        return Icons.cloud;
      case "rain":
      case "drizzle":
        return Icons.grain;
      case "thunderstorm":
        return Icons.flash_on;
      case "snow":
        return Icons.ac_unit;
      default:
        return Icons.wb_cloudy;
    }
  }
@override
Widget build(BuildContext context) {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    color: _backgroundColor(),
    elevation: 6,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // التاريخ
                Text(
                  _dateString,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                const SizedBox(width: 8),

                // الأيقونة
                Icon(_weatherIcon(), size: 25, color: Colors.white),
                const SizedBox(width: 8),

                // درجة الحرارة
               Text(
                 "${_temp.toStringAsFixed(1)}\u00B0C",
                 style: const TextStyle(
                 fontSize: 18,
                 fontWeight: FontWeight.bold,
                 color: Colors.white,
                 ),
                ),

                const SizedBox(width: 8),

                // الوصف
                Text(
                  _description,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),

                // المدينة
                Text(
                  _city,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    ),
  );
}

}