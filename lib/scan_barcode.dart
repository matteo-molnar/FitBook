import 'package:drift/drift.dart';
import 'package:fit_book/main.dart';
import 'package:fit_book/settings/settings_state.dart';
import 'package:fit_book/utils.dart';
import 'package:flutter/material.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import 'database/database.dart';

class ScanBarcode extends StatefulWidget {
  final Function(Food) onScan;
  const ScanBarcode({super.key, required this.onScan});

  @override
  createState() => _ScanBarcodeState();
}

class _ScanBarcodeState extends State<ScanBarcode> {
  bool searching = false;

  scan() async {
    var barcode = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SimpleBarcodeScannerPage(),
      ),
    );
    if (barcode is! String) return;
    if (barcode == '-1') return;

    var food = await (db.foods.select()
          ..where((tbl) => tbl.barcode.equals(barcode))
          ..limit(1))
        .getSingleOrNull();
    if (food != null) return widget.onScan(food);

    setState(() {
      searching = true;
    });

    final packageInfo = await PackageInfo.fromPlatform();
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name:
          '${packageInfo.appName}/${packageInfo.version} (brandon@presley.nz)',
    );
    SearchResult search = await OpenFoodAPIClient.searchProducts(
      const User(userId: '', password: ''),
      ProductSearchQueryConfiguration(
        parametersList: [BarcodeParameter(barcode)],
        version: ProductQueryVersion.v3,
      ),
    ).catchError(() => const SearchResult());

    if (search.products == null || search.products!.isEmpty)
      return setState(() {
        searching = false;
      });

    var companion = mapOpenFoodFacts(search.products!.first);
    if (mounted) {
      final settings = context.read<SettingsState>();
      companion = companion.copyWith(
        favorite: Value(settings.favoriteNew),
        created: Value(DateTime.now()),
        barcode: Value(barcode),
      );
    }

    final id = await db.foods.insertOne(
      companion.copyWith(created: Value(DateTime.now())),
    );
    food = await (db.foods.select()..where((u) => u.id.equals(id))).getSingle();
    widget.onScan(food);

    setState(() {
      searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(),
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.barcode_reader),
        onPressed: scan,
      );
    }
  }
}
