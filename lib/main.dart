import 'package:dynamic_color/dynamic_color.dart';
import 'package:fit_book/database.dart';
import 'package:fit_book/diary_page.dart';
import 'package:fit_book/entries_state.dart';
import 'package:fit_book/foods_page.dart';
import 'package:fit_book/graph_page.dart';
import 'package:fit_book/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

late AppDatabase db;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  db = AppDatabase();

  final settingsState = SettingsState();
  await settingsState.init();

  runApp(appProviders(settingsState));
}

Widget appProviders(SettingsState settingsState) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => settingsState),
        ChangeNotifierProvider(create: (context) => EntriesState()),
      ],
      child: const App(),
    );

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    final defaultTheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
    final defaultDark = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    );

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        title: 'FitBook',
        theme: ThemeData(
          colorScheme: settings.systemColors ? lightDynamic : defaultTheme,
          fontFamily: 'Manrope',
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: settings.systemColors ? darkDynamic : defaultDark,
          fontFamily: 'Manrope',
          useMaterial3: true,
        ),
        themeMode: settings.themeMode,
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: TabBarView(
            children: [
              DiaryPage(),
              GraphPage(),
              FoodsPage(),
            ],
          ),
        ),
        bottomNavigationBar: TabBar(
          tabs: [
            Tab(
              icon: Icon(Icons.date_range),
              text: "Diary",
            ),
            Tab(
              icon: Icon(Icons.insights),
              text: "Graph",
            ),
            Tab(
              icon: Icon(Icons.restaurant),
              text: "Foods",
            ),
          ],
        ),
      ),
    );
  }
}
