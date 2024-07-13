import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fit_book/constants.dart';
import 'package:fit_book/database/entries.dart';
import 'package:fit_book/database/foods.dart';
import 'package:fit_book/database/schema_versions.dart';
import 'package:fit_book/database/settings.dart';
import 'package:fit_book/database/weights.dart';
import 'package:fit_book/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Foods, Entries, Weights, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        final blob = await rootBundle.load('assets/my-food-data.zip');
        final archive = ZipDecoder().decodeBytes(
          blob.buffer.asUint8List(blob.offsetInBytes, blob.lengthInBytes),
        );
        List<int> bytes = archive.first.content;
        final json = utf8.decode(bytes);
        List<dynamic> rows = jsonDecode(json);
        List<Insertable<Food>> insertables = [];

        for (final row in rows) {
          Map<String, Expression<Object>> map = {};
          for (var entry in row.entries) {
            map[entry.key] = Variable(entry.value);
          }
          insertables.add(RawValuesInsertable<Food>(map));
        }

        await db.foods.insertAll(insertables);

        await (settings.insertOne(
          SettingsCompanion.insert(
            longDateFormat: "dd/MM/yy",
            shortDateFormat: 'd/M/yy',
            entryUnit: 'serving',
            foodUnit: 'grams',
            themeMode: material.ThemeMode.system.toString(),
            curveLines: false,
            diarySummary: DiarySummary.division.toString(),
            favoriteNew: false,
            notifications: false,
            selectEntryOnSubmit: false,
            showOthers: false,
            systemColors: false,
            showImages: const Value(true),
          ),
        ));
      },
      onUpgrade: stepByStep(
        from1To3: (m, schema) async {
          await m.create(schema.entries);
          await m.alterTable(TableMigration(schema.foods));
        },
        from3To4: (m, schema) async {
          await m.alterTable(TableMigration(schema.entries));
        },
        from4To5: (m, schema) async {},
        from5To6: (m, schema) async {
          await m.createIndex(
            Index(
              'Foods',
              "CREATE INDEX IF NOT EXISTS foods_name ON foods(name);",
            ),
          );
        },
        from6To7: (m, schema) async {
          await m.createTable(schema.weights);
          await m.createIndex(
            Index(
              'Foods',
              "CREATE INDEX IF NOT EXISTS foods_name ON foods(name);",
            ),
          );
        },
        from7To8: (m, schema) async {
          await m.addColumn(schema.foods, schema.foods.favorite);
        },
        from8To9: (m, schema) async {
          await m.createIndex(
            Index('Foods', 'CREATE INDEX IF NOT EXISTS foods_id ON foods(id)'),
          );
          await m.createIndex(
            Index(
              'Entries',
              'CREATE INDEX IF NOT EXISTS entries_id ON entries(id)',
            ),
          );
        },
        from9To10: (m, schema) async {
          await m.addColumn(schema.foods, schema.foods.servingUnit);
        },
        from10To11: (m, schema) async {},
        from11To12: (Migrator m, Schema12 schema) async {
          await m.addColumn(schema.foods, schema.foods.servingSize);
        },
        from12To13: (Migrator m, Schema13 schema) async {
          // Serving size wasn't properly initialized in version 12.
          // It needed to be added in onCreate as well.
          await m
              .addColumn(schema.foods, schema.foods.servingSize)
              .catchError((_) {});
        },
        from13To14: (Migrator m, Schema14 schema) async {
          await m.createTable(schema.settings);
        },
        from14To15: (Migrator m, Schema15 schema) async {
          await m.addColumn(schema.settings, schema.settings.shortDateFormat);
          final prefs = await SharedPreferences.getInstance();
          material.ThemeMode themeMode = material.ThemeMode.system;
          String longDateFormat = 'dd/MM/yy';
          String shortDateFormat = 'd/M/yy';
          String entryUnit = 'serving';
          String foodUnit = 'grams';
          DiarySummary diarySummary = DiarySummary.division;

          bool systemColors = false;
          bool curveLines = false;
          bool showOthers = false;
          bool favoriteNew = false;
          bool selectEntryOnSubmit = false;
          bool notifications = false;

          int? dailyCalories;
          int? dailyProtein;
          int? dailyFat;
          int? dailyCarbs;
          double? targetWeight;

          longDateFormat = prefs.getString('longDateFormat') ?? "dd/MM/yy";
          shortDateFormat = prefs.getString('shortDateFormat') ?? "d/M/yy";
          entryUnit = prefs.getString('entryUnit') ?? 'serving';
          foodUnit = prefs.getString('foodUnit') ?? 'grams';

          final theme = prefs.getString('themeMode');
          if (theme == "ThemeMode.system")
            themeMode = material.ThemeMode.system;
          else if (theme == "ThemeMode.light")
            themeMode = material.ThemeMode.light;
          else if (theme == "ThemeMode.dark")
            themeMode = material.ThemeMode.dark;

          final summary = prefs.getString('diarySummary');
          if (summary == DiarySummary.both.toString())
            diarySummary = DiarySummary.both;
          else if (summary == DiarySummary.division.toString())
            diarySummary = DiarySummary.division;
          else if (summary == DiarySummary.remaining.toString())
            diarySummary = DiarySummary.remaining;

          systemColors = prefs.getBool("systemColors") ?? false;
          favoriteNew = prefs.getBool("favoriteNew") ?? false;
          curveLines = prefs.getBool("curveLines") ?? true;
          showOthers = prefs.getBool("showOthers") ?? false;
          selectEntryOnSubmit = prefs.getBool("selectEntryOnSubmit") ?? false;
          notifications = prefs.getBool('notifications') ?? false;

          dailyCalories = prefs.getInt('dailyCalories');
          dailyProtein = prefs.getInt('dailyProtein');
          dailyFat = prefs.getInt('dailyFat');
          dailyCarbs = prefs.getInt('dailyCarbs');
          targetWeight = prefs.getDouble('targetWeight');

          await (schema.settings.insertOne(
            RawValuesInsertable({
              "long_date_format": Variable(longDateFormat),
              "short_date_format": Variable(shortDateFormat),
              "entry_unit": Variable(entryUnit),
              "food_unit": Variable(foodUnit),
              "theme_mode": Variable(themeMode.toString()),
              "curve_lines": Variable(curveLines),
              "diary_summary": Variable(diarySummary.toString()),
              "favorite_new": Variable(favoriteNew),
              "notifications": Variable(notifications),
              "select_entry_on_submit": Variable(selectEntryOnSubmit),
              "show_others": Variable(showOthers),
              "system_colors": Variable(systemColors),
              "daily_calories": Variable(dailyCalories),
              "daily_carb": Variable(dailyCarbs),
              "daily_fat": Variable(dailyFat),
              "daily_protein": Variable(dailyProtein),
              "target_weight": Variable(targetWeight),
            }),
          ));
        },
        from15To16: (Migrator m, Schema16 schema) async {
          await (schema.foods.update()
                ..where((u) => const CustomExpression("serving_unit is null")))
              .write(
            const RawValuesInsertable({"serving_unit": Variable("grams")}),
          );
          await (schema.foods.update()
                ..where((u) => const CustomExpression("serving_size is null")))
              .write(
            const RawValuesInsertable({"serving_size": Variable(100)}),
          );
        },
        from16To17: (Migrator m, Schema17 schema) async {
          await m.addColumn(schema.foods, schema.foods.smallImage);
          await m.addColumn(schema.foods, schema.foods.bigImage);
          await m.addColumn(schema.foods, schema.foods.imageFile);
          await m.addColumn(schema.settings, schema.settings.showImages);
        },
        from17To18: (Migrator m, Schema18 schema) async {
          // Because I forgot to add these statements in onCreate at version 17
          // we need to do it again to fix people who installed the app at 17.
          await m
              .addColumn(schema.foods, schema.foods.smallImage)
              .catchError((_) {});
          await m
              .addColumn(schema.foods, schema.foods.bigImage)
              .catchError((_) {});
          await m
              .addColumn(schema.foods, schema.foods.imageFile)
              .catchError((_) {});
        },
        from18To19: (Migrator m, Schema19 schema) async {
          await m.addColumn(schema.foods, schema.foods.created);
        },
        from19To20: (Migrator m, Schema20 schema) async {
          await m.addColumn(schema.foods, schema.foods.barcode);
        },
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fitbook.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Make sqlite3 pick a more suitable location for temporary files - the
    // one from the system may be inaccessible due to sandboxing.
    final cachebase = (await getTemporaryDirectory()).path;
    // We can't access /tmp on Android, which sqlite3 would try by default.
    // Explicitly tell it about the correct temporary directory.
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(
      file,
      logStatements: kDebugMode ? true : false,
    );
  });
}
