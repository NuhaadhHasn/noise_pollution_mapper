import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'widgets/main_app_shell.dart';
import 'services/notification_service.dart';
import 'services/sound_classification_service.dart';
import 'utils/app_logger.dart';

// Global ValueNotifier for theme management
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.dark,
);
// Global ValueNotifier for theme color management
final ValueNotifier<Color> themeColorNotifier = ValueNotifier<Color>(
  AppTheme.primaryPurple,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    AppLogger.info('Environment variables loaded successfully');
  } catch (e) {
    AppLogger.warning('Failed to load .env file (using defaults): $e');
    // App will continue with hardcoded defaults if .env doesn't exist
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable offline persistence for Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, // Cache data locally
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Unlimited cache
  );

  // Initialize notifications
  await NotificationService.initialize();
  await NotificationService.requestPermission();

  // Load saved theme preferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('dark_mode') ?? true;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // Load saved theme color
  final savedColorValue = prefs.getInt('theme_color');
  if (savedColorValue != null) {
    themeColorNotifier.value = Color(savedColorValue);
  }

  // Test TFLite model loading (Step 1-3: Sound Classification)
  await _testModelLoading();

  // Initialize Sound Classification Service (Step 5: Sound Classification)
  await _initializeSoundClassification();

  runApp(const MyApp());
}

/// Test function to verify YAMNet TFLite model loads correctly
Future<void> _testModelLoading() async {
  try {
    AppLogger.debug('[Sound Classification] Testing YAMNet model loading...');

    // Load the YAMNet TFLite model
    final interpreter = await Interpreter.fromAsset(
      'assets/models/yamnet.tflite',
    );

    // Get model input/output details
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;

    AppLogger.info('[Sound Classification] YAMNet model loaded successfully!');
    AppLogger.debug('Input shape: $inputShape');
    AppLogger.debug('Output shape: $outputShape');
    AppLogger.debug('Model ready for sound classification');

    // Close interpreter for now (will be reinitialized in SoundClassificationService)
    interpreter.close();
  } catch (e) {
    AppLogger.error('[Sound Classification] Failed to load model', e);
    AppLogger.warning('Sound classification will be disabled');
  }
}

/// Initialize Sound Classification Service for real-time audio classification
Future<void> _initializeSoundClassification() async {
  try {
    AppLogger.debug(
      '[Sound Classification] Initializing classification service...',
    );

    final service = SoundClassificationService();
    final initialized = await service.initialize();

    if (initialized) {
      AppLogger.info(
        '[Sound Classification] Service ready for real-time classification',
      );
      AppLogger.debug(
        'Classification interval: ${SoundClassificationService.classificationIntervalSeconds}s',
      );
      AppLogger.debug(
        'Confidence threshold: ${(SoundClassificationService.confidenceThreshold * 100).toStringAsFixed(0)}%',
      );
    } else {
      AppLogger.warning('[Sound Classification] Service initialization failed');
    }
  } catch (e) {
    AppLogger.error('[Sound Classification] Error initializing service', e);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: themeColorNotifier,
          builder: (context, themeColor, child) {
            // Generate themes dynamically based on selected color
            final lightTheme = AppTheme.generateLightTheme(themeColor);
            final darkTheme = AppTheme.generateDarkTheme(themeColor);

            return MaterialApp(
              title: 'Urban Noise Pollution Mapper',
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: themeMode,
              debugShowCheckedModeBanner: false,
              home: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  // Check if user is logged in
                  if (snapshot.connectionState == ConnectionState.active) {
                    final user = snapshot.data;
                    if (user == null) {
                      // Not logged in - show splash/onboarding/login flow
                      return const SplashScreen();
                    } else {
                      // Already logged in - go to main app shell with navigation
                      return const MainAppShell();
                    }
                  }
                  // Loading state
                  return Scaffold(
                    backgroundColor: themeMode == ThemeMode.dark
                        ? AppTheme.darkBackground
                        : AppTheme.lightBackground,
                    body: Center(
                      child: CircularProgressIndicator(color: themeColor),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times: testing '),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
