import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'utils/localization_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:plant_diagnosis_app/utils/localization_helper.dart';


// ================= Database Helper =================
class DatabaseHelper {
  static Database? _db;

  static String appLanguageCode = 'en';
  static bool get isArabic => appLanguageCode == 'ar';

  static String get nameCol => isArabic ? 'name' : 'name_en';
  static String get symptomsCol => isArabic ? 'symptoms' : 'symptoms_en';
  static String get causeCol => isArabic ? 'cause' : 'cause_en';
  static String get preventiveCol =>
      isArabic ? 'preventive_measures' : 'preventive_measures_en';
  static String get chemicalCol =>
      isArabic ? 'chemical_treatment' : 'chemical_treatment_en';
  static String get alternativeCol =>
      isArabic ? 'alternative_treatment' : 'alternative_treatment_en';

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;
    if (kIsWeb) throw Exception("Web uses JSON, not SQLite");

    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, "plantix_final.db");

    bool exists = await File(path).exists();
    if (!exists) {
      print("üìå ŸÜÿ≥ÿÆ ŸÇÿßÿπÿØÿ© ÿßŸÑÿ®ŸäÿßŸÜÿßÿ™ ŸÖŸÜ assets ŸÑÿ£ŸàŸÑ ŸÖÿ±ÿ©...");
      ByteData data = await rootBundle.load("assets/plantix_final.db");
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }

    _db = await openDatabase(path, readOnly: true);
    return _db!;
  }

  // ================= Web JSON =================
  static Map<int, dynamic> _jsonData = {};

  static Future<void> loadJson(String assetPath) async {
    if (!kIsWeb) return;
    final data = await rootBundle.loadString(assetPath);
    final list = json.decode(data) as List<dynamic>;
    _jsonData.clear();
    for (var crop in list) {
      _jsonData[crop['id']] = crop;
    }
  }

  // ==================== Methods ====================
  static Future<List<Map<String, dynamic>>> getCrops() async {
    if (kIsWeb) return getCropsFromJson();
    final db = await getDatabase();
    return await db.query(
      'crops',
      columns: ['id', nameCol + ' as name', 'name_en'],
    );
  }

  static Future<List<Map<String, dynamic>>> getStagesByCrop(int cropId) async {
    final db = await getDatabase();
    return await db.rawQuery('''
      SELECT DISTINCT s.id, s.$nameCol AS name
      FROM stages s
      JOIN disease_crop_stage dcs ON dcs.stage_id = s.id
      WHERE dcs.crop_id = ?
      ORDER BY s.id
    ''', [cropId]);
  }

  static Future<List<Map<String, dynamic>>> getDiseasesByCropAndStage(
      int cropId, int stageId) async {
    final db = await getDatabase();
    return await db.rawQuery('''
      SELECT DISTINCT d.id,
             d.$nameCol AS name,
             d.default_image,
             d.$symptomsCol AS symptoms,
             d.$causeCol AS cause,
             d.$preventiveCol AS preventive_measures,
             d.$chemicalCol AS chemical_treatment,
             d.$alternativeCol AS alternative_treatment
      FROM diseases d
      JOIN disease_crop_stage ds ON ds.disease_id = d.id
      WHERE ds.stage_id = ? AND ds.crop_id = ?
    ''', [stageId, cropId]);
  }

  // ================= Web JSON Methods =================
  static Future<List<Map<String, dynamic>>> getCropsFromJson() async {
    return _jsonData.values.map((c) => {
          'id': c['id'],
          'name': isArabic ? c['name'] : c['name_en'],
          'name_en': c['name_en'],
        }).toList();
  }

  static Future<List<Map<String, dynamic>>> getStagesByCropFromJson(
      int cropId) async {
    final crop = _jsonData[cropId];
    if (crop == null) return [];
    final stages = crop['stages'] as List<dynamic>;
    return stages.map((s) => {
          'id': s['id'],
          'name': isArabic ? s['name'] : s['name_en'],
          'diseases': s['diseases'],
        }).toList();
  }

  static Future<List<Map<String, dynamic>>> getDiseasesByCropAndStageFromJson(
      int cropId, int stageId) async {
    final stages = await getStagesByCropFromJson(cropId);
    final stage =
        stages.firstWhere((s) => s['id'] == stageId, orElse: () => {});
    if (stage.isEmpty) return [];
    final diseases = stage['diseases'] as List<dynamic>;
    return diseases.map((d) => {
          'id': d['id'],
          'name': isArabic ? d['name'] : d['name_en'],
          'default_image': d['default_image'],
          'symptoms': isArabic ? d['symptoms'] : d['symptoms_en'],
          'cause': isArabic ? d['cause'] : d['cause_en'],
          'preventive_measures': (isArabic
                  ? d['preventive_measures']
                  : d['preventive_measures_en'])
              .join(", "),
          'chemical_treatment':
              isArabic ? d['chemical_treatment'] : d['chemical_treatment_en'],
          'alternative_treatment': isArabic
              ? d['alternative_treatment']
              : d['alternative_treatment_en'],
        }).toList();
  }

  // ================= Login via backend =================
  static Future<int?> loginFarmer(String email, String password) async {
    final uri = Uri.parse('http://localhost:8000/register_or_login'); // ÿπÿØŸëŸÑ ÿ≠ÿ≥ÿ® ÿ≥Ÿäÿ±ŸÅÿ±ŸÉ
    try {
      final response = await http.post(uri, body: {
        'email': email,
        'password': password,
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['farmer_id'] as int?;
      } else {
        return null;
      }
    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }
}

// ================== LoginPage ==================
class LoginPage extends StatefulWidget {
  final Function(String, String, int) onLoginSuccess;
  const LoginPage({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    final farmerId = await DatabaseHelper.loginFarmer(email, password);
    if (farmerId != null) {
      widget.onLoginSuccess(email, password, farmerId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid credentials")));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: "Email"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Password"),
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _login,
                          child: const Text("Login"),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}





void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await DatabaseHelper.loadJson("assets/plant_relational.json");
  } else if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  final farmerId = prefs.getInt("farmer_id"); // ŸáŸÑ ÿ™ŸÖ ÿ™ÿ≥ÿ¨ŸäŸÑ ÿßŸÑÿØÿÆŸàŸÑ ŸÖÿ≥ÿ®ŸÇŸãÿßÿü

  runApp(MyApp(initialFarmerId: farmerId));
}

class MyApp extends StatefulWidget {
  final int? initialFarmerId;
  const MyApp({Key? key, this.initialFarmerId}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');
  int? farmerId;

  @override
  void initState() {
    super.initState();
    farmerId = widget.initialFarmerId;
  }

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
      DatabaseHelper.appLanguageCode = locale.languageCode;
    });
  }

  void _onLoginSuccess(String email, String password, int farmerId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('farmer_id', farmerId);
    await prefs.setString('email', email);      // ÿ≠ŸÅÿ∏ ÿßŸÑÿ®ÿ±ŸäÿØ
    await prefs.setString('password', password); // ÿ≠ŸÅÿ∏ ŸÉŸÑŸÖÿ© ÿßŸÑŸÖÿ±Ÿàÿ±
    setState(() => this.farmerId = farmerId);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Diagnosis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, fontFamily: 'Arial'),
      locale: _locale,
      supportedLocales: const [Locale('en', ''), Locale('ar', '')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ‚úÖ ÿßŸÑÿ™ÿ®ÿØŸäŸÑ ÿ®ŸäŸÜ LoginPage Ÿà SplashPage
      home: farmerId == null
          ? LoginPage(onLoginSuccess: _onLoginSuccess)
          : SplashScreen(onLocaleChange: _setLocale),
    );
  }
}
// ================== Splash Screen ==================
class SplashScreen extends StatefulWidget {
  final Function(Locale) onLocaleChange;
  const SplashScreen({required this.onLocaleChange, Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  late AnimationController _buttonsController;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();

    // ‚úÖ Logo Animation
    _logoController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation =
        CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoController.forward();

    // ‚úÖ Buttons Animation
    _buttonsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideAnimations = List.generate(5, (index) {
      final start = index * 0.1;
      final end = start + 0.5;
      return Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _buttonsController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });

    _buttonsController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _buttonsController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedButton(
      {required String text,
      required IconData icon,
      required VoidCallback onPressed,
      required Animation<Offset> animation}) {
    return SlideTransition(
      position: animation,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[200], // ‚úÖ ŸÑŸàŸÜ ŸÖŸàÿ≠ŸëÿØ
            foregroundColor: Colors.black87,
            minimumSize: const Size(double.infinity, 55),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(text, style: const TextStyle(fontSize: 17)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFFFFFFF)], // üåø ÿÆŸÑŸÅŸäÿ© ŸÖÿ±Ÿäÿ≠ÿ©
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ‚úÖ Logo
                    CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset("assets/logo.png", fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ‚úÖ Welcome text
                    Text(
                      t.welcomeText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 35),

                    // ‚úÖ Buttons with slide animation
                    _buildAnimatedButton(
                      text: t.diagnosePlant,
                      icon: Icons.search,
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => DiagnosisPage()));
                      },
                      animation: _slideAnimations[0],
                    ),
                    _buildAnimatedButton(
                      text: t.contactExperts,
                      icon: Icons.person,
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => FarmerQuestionsPage()));
                      },
                      animation: _slideAnimations[1],
                    ),
                    _buildAnimatedButton(
                      text: t.pestsDiseases, // ‚úÖ ŸÖÿ™ÿ±ÿ¨ŸÖ ÿ®ÿØŸÑ ÿßŸÑŸÜÿµ ÿßŸÑÿ´ÿßÿ®ÿ™
                      icon: Icons.bug_report,
                      onPressed: () {
                      Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PestsDiseasesPage()),
                        );
                        },
                      animation: _slideAnimations[2],
                    ),

                    _buildAnimatedButton(
                      text: t.awarenessGuide,
                      icon: Icons.menu_book,
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => AwarenessPage()));
                      },
                      animation: _slideAnimations[3],
                    ),
                    _buildAnimatedButton(
                      text: t.changeLanguage,
                      icon: Icons.language,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(t.changeLanguage),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.language),
                                  title: const Text('English'),
                                  onTap: () {
                                    widget.onLocaleChange(const Locale('en'));
                                    Navigator.pop(context);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.language),
                                  title: const Text('ÿßŸÑÿπÿ±ÿ®Ÿäÿ©'),
                                  onTap: () {
                                    widget.onLocaleChange(const Locale('ar'));
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      animation: _slideAnimations[4],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================== Diagnosis Page ==================
class DiagnosisPage extends StatefulWidget {
  const DiagnosisPage({Key? key}) : super(key: key);

  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  File? _imageFile;
  Uint8List? _webImage;
  bool _loading = false;
  String? _disease;
  double? _confidence;
  String? _treatment;
  final picker = ImagePicker();

  List<Map<String, dynamic>> previousDiagnoses = [];

  @override
  void initState() {
    super.initState();
    _loadPreviousDiagnoses();
  }

  Future<void> _loadPreviousDiagnoses() async {
    try {
      final data = await fetchPreviousDiagnoses();
      setState(() => previousDiagnoses = data);
    } catch (e) {
      print("? Error fetching previous diagnoses: $e");
    }
  }

  Future<void> pickImage() async {
    XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    Uint8List imageBytes = await pickedFile.readAsBytes();
    setState(() {
      if (kIsWeb)
        _webImage = imageBytes;
      else
        _imageFile = File(pickedFile.path ?? '');
    });

    await diagnoseAndSave(imageBytes, pickedFile.name);
  }

  Future<void> diagnoseAndSave(Uint8List imageBytes, String filename) async {
    setState(() {
      _loading = true;
      _disease = null;
      _confidence = null;
      _treatment = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final farmerId = prefs.getInt('farmer_id') ?? 0;

      final uri = Uri.parse('http://localhost:8000/predict');
      final request = http.MultipartRequest('POST', uri);
      request.fields['farmer_id'] = farmerId.toString();
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      if (response.statusCode != 200) throw Exception('Failed to diagnose');

      final data = json.decode(respStr);
      final diseaseId = data['disease_id'];
      final confidence = data['confidence'];
      final treatment = data['treatment'] ?? "";

      final diseaseMap = LocalizationHelper.getDiseaseMap(context);
      final localizedDisease = diseaseMap[diseaseId] ?? diseaseId;

      setState(() {
        _disease = localizedDisease;
        _confidence = confidence != null ? (confidence) : null;
        _treatment = treatment;
      });

      // Õ›Ÿ «· ‘ŒÌ’ ›Ì ﬁ«⁄œ… «·»Ì«‰« 
      final saveUri = Uri.parse('http://localhost:8000/save_diagnosis');
      final base64Image = base64Encode(imageBytes);

      await http.post(
        saveUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'farmer_id': farmerId,
          'disease_id': diseaseId,
          'confidence': confidence,
          'image': base64Image,
          'treatment': treatment,
          'expert_id': 0
        }),
      );

      await _loadPreviousDiagnoses();
    } catch (e) {
      print("? Error diagnosing or saving: $e");
      setState(() => _disease = "ÕœÀ Œÿ√ √À‰«¡ «· ‘ŒÌ’");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> fetchPreviousDiagnoses() async {
    final prefs = await SharedPreferences.getInstance();
    final farmerId = prefs.getInt('farmer_id');
    if (farmerId == null) return [];

    final uri = Uri.parse('http://localhost:8000/previous_diagnoses/$farmerId');
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('Failed to fetch previous diagnoses');

    final List data = json.decode(response.body);
	// ? ›· —… «·‰ «∆Ã »ÕÌÀ expert_id == 0 ›ﬁÿ
    final filtered = data.where((e) {
    final expertId = e['expert_id'] ?? 0;
    return expertId == 0;
    }).toList();

    return filtered.map((e) => e as Map<String, dynamic>).toList();

    //return data.map((e) => e as Map<String, dynamic>).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.diagnosePlant), backgroundColor: Colors.green[700]),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ? «·⁄„Êœ «·√Ì”— («· ‘ŒÌ’ «·Õ«·Ì)
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: pickImage,
                    icon: const Icon(Icons.add_a_photo),
                    label: Text(loc.selectImage),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_imageFile != null || _webImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _imageFile != null
                          ? Image.file(_imageFile!, height: 300, fit: BoxFit.cover)
                          : Image.memory(_webImage!, height: 300, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 20),

                  if (_loading)
                    const CircularProgressIndicator(color: Colors.green),

                  if (_disease != null && !_loading)
                    Card(
                      color: Colors.green[50],
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${loc.result}: $_disease",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _disease!.toLowerCase().contains("Œÿ√")
                                        ? Colors.red
                                        : Colors.green[800])),
                            const SizedBox(height: 10),
                            if (_confidence != null)
                              Text(
                                "${_confidence!.toStringAsFixed(1)}% ${loc.confidence}",
                                style: const TextStyle(color: Colors.black54),
                              ),
                            const SizedBox(height: 10),
                            if (_treatment != null && _treatment!.isNotEmpty)
                              Text("${loc.treatment}: $_treatment",
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 20),

            // ? «·⁄„Êœ «·√Ì„‰ («· ‘ŒÌ’«  «·”«»ﬁ…)
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.previousDiagnos,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700])),
                  const SizedBox(height: 10),
                  if (previousDiagnoses.isEmpty)
                    Text(loc.noPreviousDiagnoses, style: TextStyle(color: Colors.grey[600])),
                  ...previousDiagnoses.map((diag) {
                    final imageBytes = base64Decode(diag['image']);
                    final diseaseId = diag['disease'];
                    final confidence = diag['confidence'] ?? 0.0;
                    final treatment = diag['treatment'] ?? "";
                    final diseaseMap = LocalizationHelper.getDiseaseMap(context);
                    final localizedDisease = diseaseMap[diseaseId] ?? diseaseId;

                    return Card(
                      color: Colors.white,
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.memory(
                              imageBytes,
                              height: 120, // ?  ’€Ì— «·’Ê—…
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${loc.result}: $localizedDisease",
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800])),
                                const SizedBox(height: 4),
                                Text("${(confidence).toStringAsFixed(1)}% ${loc.confidence}",
                                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                if (treatment.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text("${loc.treatment}: $treatment",
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black87)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== Pests & Diseases Page ==================
class PestsDiseasesPage extends StatefulWidget {
  const PestsDiseasesPage({Key? key}) : super(key: key);
  @override
  State<PestsDiseasesPage> createState() => _PestsDiseasesPageState();
}

class _PestsDiseasesPageState extends State<PestsDiseasesPage> {
  List<Map<String, dynamic>> crops = [];
  int? selectedCropId;
  List<Map<String, dynamic>> stages = [];
  Map<int, List<Map<String, dynamic>>> stageDiseases = {};

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    final data = kIsWeb
        ? await DatabaseHelper.getCropsFromJson()
        : await DatabaseHelper.getCrops();
    print("üìå Crops Loaded: $data"); // ‚Üê ÿ™ÿ≠ŸÇŸÇ
    setState(() => crops = data);
  }

  Future<void> _loadStages(int cropId) async {
    final data = kIsWeb
        ? await DatabaseHelper.getStagesByCropFromJson(cropId)
        : await DatabaseHelper.getStagesByCrop(cropId);
    setState(() {
      stages = data;
      stageDiseases.clear();
    });
    for (var stage in data) {
      final diseases = kIsWeb
          ? await DatabaseHelper.getDiseasesByCropAndStageFromJson(
              cropId, stage['id'])
          : await DatabaseHelper.getDiseasesByCropAndStage(
              cropId, stage['id']);
      setState(() => stageDiseases[stage['id']] = diseases);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!; // ‚úÖ ÿßŸÑÿ™ÿ±ÿ¨ŸÖÿ©

    return Scaffold(
      appBar: AppBar(title: Text(t.pestsDiseases)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // üîΩ ÿßŸÑŸÇÿßÿ¶ŸÖÿ© ÿßŸÑŸÖŸÜÿ≥ÿØŸÑÿ© ŸÑŸÑŸÖÿ≠ÿßÿµŸäŸÑ
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: t.selectCrop,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              value: selectedCropId,
              items: crops.map((crop) {
                final imageName = crop['name_en']?.toString() ?? '';
                // ‚úÖ ÿπÿ±ÿ∂ ÿßÿ≥ŸÖ ÿßŸÑŸÖÿ≠ÿµŸàŸÑ ÿ≠ÿ≥ÿ® ÿßŸÑŸÑÿ∫ÿ©
                final cropName = Localizations.localeOf(context).languageCode == 'ar'
                    ? crop['name']
                    : crop['name_en'] ?? crop['name'];

                return DropdownMenuItem<int>(
                  value: crop['id'],
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/plantix_icons/$imageName.jpg',
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported, size: 24),
                      ),
                      const SizedBox(width: 8),
                      Text(cropName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedCropId = value);
                  _loadStages(value);
                }
              },
            ),
            const SizedBox(height: 20),

            // üìå ÿπÿ±ÿ∂ ÿßŸÑŸÖÿ±ÿßÿ≠ŸÑ ŸàÿßŸÑÿ£ŸÖÿ±ÿßÿ∂
            Expanded(
              child: selectedCropId == null
                  ? Center(child: Text(t.noCropSelected))
                  : ListView(
                      children: stages.map((stage) {
                        final diseases = stageDiseases[stage['id']] ?? [];
                        return ExpansionTile(
                          title: Text("${t.stage}: ${stage['name']}"),
                          children: diseases.isEmpty
                              ? [ListTile(title: Text(t.noDiseases))]
                              : diseases.map((disease) {
                                  return Card(
                                    margin: const EdgeInsets.all(8),
                                    child: ListTile(
                                      leading: disease['default_image'] != null
                                          ? Image.asset(
                                              "assets/disease_images/${disease['default_image']}",
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.bug_report),
                                            )
                                          : const Icon(Icons.bug_report),
                                      title: Text(disease['name'] ?? ""),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DiseaseDetailsPage(
                                              disease: disease,
                                              details: disease,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }).toList(),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== Disease Details ==================
class DiseaseDetailsPage extends StatelessWidget {
  final Map<String, dynamic> disease;
  final Map<String, dynamic> details;

  const DiseaseDetailsPage({
    Key? key,
    required this.disease,
    required this.details,
  }) : super(key: key);

  Widget _buildDetailSection(String title, String? content) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(disease['name'] ?? t.diseaseDetails),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (disease['default_image'] != null)
              Center(
                child: Image.asset(
                  "assets/disease_images/${disease['default_image']}",
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 100),
                ),
              ),
            const SizedBox(height: 16),
            _buildDetailSection(t.symptoms, disease['symptoms']),
            _buildDetailSection(t.cause, disease['cause']),
            _buildDetailSection(
                t.preventiveMeasures, disease['preventive_measures']),
            _buildDetailSection(
                t.chemicalTreatment, disease['chemical_treatment']),
            _buildDetailSection(
                t.alternativeTreatment, disease['alternative_treatment']),
          ],
        ),
      ),
    );
  }
}

// ================== Awareness Page ==================

class AwarenessPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.awarenessGuide)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTile(
            icon: Icons.eco,
            title: t.basicFarming,
            imagePath: 'assets/images/soil.jpg',
            content: [
              t.soilAdvice,
              t.sunAdvice,
              t.wateringAdvice,
            ],
          ),
          _buildTile(
            icon: Icons.shield,
            title: t.diseasePrevention,
            imagePath: 'assets/images/protection.jpg',
            content: [
              t.toolSanitation,
              t.cropRotation,
              t.seedSelection,
            ],
          ),
          _buildTile(
            icon: Icons.bug_report,
            title: t.naturalPestControl,
            imagePath: 'assets/images/pests.jpg',
            content: [
              t.plantRepellents,
              t.organicSprays,
              t.beneficialInsects,
            ],
          ),
          _buildTileWithWidget(
            icon: Icons.medical_information,
            title: t.commonDiseases,
            imagePath: 'assets/images/diseases.jpg',
            child: _diseaseTable(t),
          ),
          _buildTileWithWidget(
            icon: Icons.calendar_month,
            title: t.seasonalTips,
            imagePath: 'assets/images/seasons.jpg',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _subSection('üå∏ ${t.spring}', [t.spring1, t.spring2]),
                _subSection('‚òÄÔ∏è ${t.summer}', [t.summer1, t.summer2]),
                _subSection('üçÇ ${t.autumn}', [t.autumn1, t.autumn2]),
                _subSection('‚ùÑÔ∏è ${t.winter}', [t.winter1, t.winter2]),
              ],
            ),
          ),
          _buildTile(
            icon: Icons.menu_book,
            title: t.resources,
            imagePath: 'assets/images/books.jpg',
            content: [
              'FAO: https://www.fao.org',
              'PlantVillage: https://plantvillage.psu.edu',
              t.youtubeChannels,
            ],
          ),
          _buildTile(
            icon: Icons.support_agent,
            title: t.needHelp,
            imagePath: 'assets/images/support.jpg',
            content: [t.contactExpertsInfo],
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String imagePath,
    required List<String> content,
  }) {
    return ExpansionTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      children: [
        const SizedBox(height: 8),
        Image.asset(imagePath, height: 150, fit: BoxFit.cover),
        const SizedBox(height: 8),
        ...content.map((item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(item, style: const TextStyle(fontSize: 16)),
            )),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTileWithWidget({
    required IconData icon,
    required String title,
    required String imagePath,
    required Widget child,
  }) {
    return ExpansionTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      children: [
        const SizedBox(height: 8),
        Image.asset(imagePath, height: 150, fit: BoxFit.cover),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: child),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _subSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('‚Ä¢ $item', style: const TextStyle(fontSize: 15)),
              )),
        ],
      ),
    );
  }

  Widget _diseaseTable(AppLocalizations t) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FractionColumnWidth(0.25),
        1: FractionColumnWidth(0.35),
        2: FractionColumnWidth(0.4),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFDEFDE0)),
          children: [
            _tableCell(t.disease),
            _tableCell(t.symptoms),
            _tableCell(t.treatment),
          ],
        ),
        _diseaseRow('ÿßŸÑÿ®Ÿäÿßÿ∂ ÿßŸÑÿØŸÇŸäŸÇŸä', 'ÿ∑ÿ®ŸÇÿ© ÿ®Ÿäÿ∂ÿßÿ° ÿπŸÑŸâ ÿßŸÑÿ£Ÿàÿ±ÿßŸÇ', 'ÿ™ŸáŸàŸäÿ© ÿ¨ŸäÿØÿ© + ÿ±ÿ¥ ÿ®ÿßŸÑŸÉÿ®ÿ±Ÿäÿ™'),
        _diseaseRow('ÿßŸÑŸÑŸÅÿ≠ÿ© ÿßŸÑŸÖÿ™ÿ£ÿÆÿ±ÿ©', 'ÿ®ŸÇÿπ ÿ≥ŸàÿØÿßÿ° ÿπŸÑŸâ ÿßŸÑÿ∑ŸÖÿßÿ∑ŸÖ', 'ŸÖÿ®ŸäÿØ ŸÜÿ≠ÿßÿ≥Ÿä + ÿ•ÿ≤ÿßŸÑÿ© ÿßŸÑŸÖÿµÿßÿ®'),
        _diseaseRow('ÿßŸÑÿ™ÿπŸÅŸÜ ÿßŸÑÿ¨ÿ∞ÿ±Ÿä', 'ÿßÿµŸÅÿ±ÿßÿ± ŸàŸÖŸàÿ™ ÿ™ÿØÿ±Ÿäÿ¨Ÿä', 'ÿ™ÿ≠ÿ≥ŸäŸÜ ÿßŸÑÿ™ÿµÿ±ŸäŸÅ + ÿ™ŸÇŸÑŸäŸÑ ÿßŸÑÿ±Ÿä'),
        _diseaseRow('ÿßŸÑŸÖŸÜ', 'ÿ≠ÿ¥ÿ±ÿßÿ™ ÿµÿ∫Ÿäÿ±ÿ© ÿ™ŸÖÿ™ÿµ ÿßŸÑÿπÿµÿßÿ±ÿ©', 'ÿ®ÿÆÿßÿÆ ÿßŸÑŸÜŸäŸÖ + ŸÖÿßÿ° Ÿàÿµÿßÿ®ŸàŸÜ'),
      ],
    );
  }

  TableRow _diseaseRow(String a, String b, String c) {
    return TableRow(
      children: [
        _tableCell(a),
        _tableCell(b),
        _tableCell(c),
      ],
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, style: const TextStyle(fontSize: 15)),
    );
  }
}


// ================== Experts Page ==================
// ================== Farmer Questions Page (Final - With Unanswered Section) ==================
class FarmerQuestionsPage extends StatefulWidget {
  const FarmerQuestionsPage({Key? key}) : super(key: key);

  @override
  State<FarmerQuestionsPage> createState() => _FarmerQuestionsPageState();
}

class _FarmerQuestionsPageState extends State<FarmerQuestionsPage> {
  File? _imageFile;
  Uint8List? _webImage;
  bool _loading = false;
  final picker = ImagePicker();
  final TextEditingController _questionController = TextEditingController();

  List<Map<String, dynamic>> answered = [];
  List<Map<String, dynamic>> unanswered = [];
  int? _farmerId;

  @override
  void initState() {
    super.initState();
    _loadFarmerIdAndData();
  }

  Future<void> _loadFarmerIdAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _farmerId = prefs.getInt('farmer_id') ?? 0;
    await _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    if (_farmerId == null) return;

    try {
      final uri = Uri.parse("http://localhost:8000/get_farmer_questions/$_farmerId");
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        print("Response code: ${response.statusCode}");
        print("Response body: ${response.body}");

        setState(() {
          answered = data
              .where((q) => q['status'] == 1)
              .map((e) => e as Map<String, dynamic>)
              .toList();

          unanswered = data
              .where((q) => q['status'] == 0)
              .map((e) => e as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (e) {
      print("? Error fetching questions: $e");
    }
  }

  Future<void> _pickImage() async {
    XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    Uint8List imageBytes = await pickedFile.readAsBytes();

    setState(() {
      if (kIsWeb)
        _webImage = imageBytes;
      else
        _imageFile = File(pickedFile.path);
    });
  }

  Future<void> _sendQuestion() async {
    final loc = AppLocalizations.of(context)!;
    if (_questionController.text.trim().isEmpty) return;
    if (_farmerId == null) return;
    if (_imageFile == null && _webImage == null) return;

    Uint8List imageBytes;
    String filename = "question_image.png";

    if (kIsWeb) {
      imageBytes = _webImage!;
    } else {
      imageBytes = await _imageFile!.readAsBytes();
      filename = _imageFile!.path.split("/").last;
    }

    setState(() => _loading = true);

    try {
      final uri = Uri.parse("http://localhost:8000/send_question");
      final request = http.MultipartRequest('POST', uri);
      request.fields['farmer_id'] = _farmerId.toString();
      request.fields['question'] = _questionController.text.trim();
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));

      final response = await request.send();
      if (response.statusCode == 200) {
        _questionController.clear();
        setState(() {
          _imageFile = null;
          _webImage = null;
        });
        await _fetchQuestions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.snackbar_question_sent)),
        );
      }
    } catch (e) {
      print("? Error sending question: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, {bool answered = false}) {
  final loc = AppLocalizations.of(context)!;
  Uint8List? imageBytes;
  try {
    if (q['image'] != null && q['image'].toString().isNotEmpty) {
      imageBytes = base64Decode(q['image']);
    }
  } catch (e) {
    print("? Error decoding image: $e");
  }

  final questionText = q['question'] ?? "";
  final answerText = q['answer'] ?? "";

  return Card(
    color: answered ? Colors.green[50] : Colors.white,
    elevation: 3,
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ====== «·”ƒ«· ======
          Text(
            "${loc.label_question} $questionText",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: answered ? Colors.green[800] : Colors.black87,
            ),
          ),

          // ====== «·’Ê—… (≈‰ ÊÃœ ) ======
          if (imageBytes != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                imageBytes,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          ],

          // ====== «·≈Ã«»… (≈‰ ﬂ«‰  „ÊÃÊœ…) ======
          if (answered && answerText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "${loc.label_answer} $answerText",
              style: const TextStyle(color: Colors.blue, fontSize: 14),
            ),
          ],
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.farmer_page_title),
        backgroundColor: Colors.green[700],
      ),
      backgroundColor: Colors.grey[100],
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===================== «·⁄„Êœ «·√Ì”— («·√”∆·… «·„Ã«»…) =====================
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.tab_answered,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700])),
                        const SizedBox(height: 10),
                        if (answered.isEmpty)
                          Text(loc.noPreviousDiagnoses,
                              style: TextStyle(color: Colors.grey[600])),
                        ...answered.map((q) => _buildQuestionCard(q, answered: true)).toList(),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // ===================== «·⁄„Êœ «·√Ì„‰ (≈—”«· ”ƒ«· ÃœÌœ + «·√”∆·… €Ì— «·„Ã«»…) =====================
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ========== ‰„Ê–Ã ≈—”«· ”ƒ«· ==========
                        TextField(
                          controller: _questionController,
                          decoration: InputDecoration(
                            labelText: loc.label_write_question,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_a_photo),
                          label: Text(loc.button_pick_image),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_imageFile != null || _webImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _imageFile != null
                                ? Image.file(_imageFile!, height: 250, fit: BoxFit.cover)
                                : Image.memory(_webImage!, height: 250, fit: BoxFit.cover),
                          ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _sendQuestion,
                          child: Text(loc.button_send_question),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // ========== «·√”∆·… €Ì— «·„Ã«»… ==========
                        Text(loc.tab_unanswered,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700])),
                        const SizedBox(height: 10),
                        if (unanswered.isEmpty)
                          Text(loc.noPreviousDiagnoses,
                              style: TextStyle(color: Colors.grey[600])),
                        ...unanswered.map((q) => _buildQuestionCard(q)).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
