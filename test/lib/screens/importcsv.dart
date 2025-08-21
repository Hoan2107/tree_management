import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CsvImporter {
  bool isImporting = false;
  int totalImported = 0;
  int totalRecords = 0;
  int invalidRecords = 0;
  List<List<List<double>>> polygons = [];
  List<String> areaNames = [];
  List<Map<String, dynamic>> areaFeatures = [];

  Future<void> loadGeoJson() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/test.geojson');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final features = jsonData['features'] ?? [];

      List<List<List<double>>> allPolygons = [];
      List<String> names = [];
      List<Map<String, dynamic>> featuresList = [];

      for (var feature in features) {
        final properties = feature['properties'] ?? {};
        final areaName = properties['name']?.toString() ?? 'Unknown';
        names.add(areaName);
        featuresList.add({
          'name': areaName,
          'properties': properties,
        });

        if (feature['geometry']['type'] == 'MultiPolygon') {
          final coordinates = feature['geometry']['coordinates'] as List;
          for (var polygonGroup in coordinates) {
            if (polygonGroup.isNotEmpty) {
              final outerRing = polygonGroup[0] as List;
              final List<List<double>> processedPolygon =
                  outerRing.map<List<double>>((point) {
                return [point[0].toDouble(), point[1].toDouble()];
              }).toList();
              allPolygons.add(processedPolygon);
            }
          }
        } else if (feature['geometry']['type'] == 'Polygon') {
          final coordinates = feature['geometry']['coordinates'] as List;
          if (coordinates.isNotEmpty) {
            final outerRing = coordinates[0] as List;
            final List<List<double>> processedPolygon =
                outerRing.map<List<double>>((point) {
              return [point[0].toDouble(), point[1].toDouble()];
            }).toList();
            allPolygons.add(processedPolygon);
          }
        }
      }

      polygons = allPolygons;
      areaNames = names;
      areaFeatures = featuresList;

      debugPrint('Loaded ${polygons.length} polygons from GeoJSON');
    } catch (e) {
      debugPrint('Error loading GeoJSON: $e');
      throw Exception('Lỗi khi tải file GeoJSON: ${e.toString()}');
    }
  }

  String? getAreaForPoint(double lat, double lng) {
    if (polygons.isEmpty || areaNames.isEmpty) return null;

    final point = [lng, lat];

    for (int i = 0; i < polygons.length; i++) {
      if (_pointInPolygon(point, polygons[i])) {
        return areaNames[i];
      }
    }
    return null;
  }

  bool _pointInPolygon(List<double> point, List<List<double>> polygon) {
    double x = point[0];
    double y = point[1];
    bool inside = false;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      double xi = polygon[i][0];
      double yi = polygon[i][1];
      double xj = polygon[j][0];
      double yj = polygon[j][1];

      bool intersect =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  Future<void> importCSVFromFile(BuildContext context, File file) async {
    final rawData = await _parseCSV(file);
    await _processData(context, rawData);
  }

  Future<void> importCSVFromContent(
      BuildContext context, String content) async {
    final fields = const CsvToListConverter().convert(content);
    final rawData = _parseCSVFields(fields);
    await _processData(context, rawData);
  }

  List<Map<String, dynamic>> _parseCSVFields(List<List<dynamic>> fields) {
    return fields
        .sublist(1)
        .map((row) {
          try {
            return {
              "name": row[0].toString().trim(),
              "lat": double.tryParse(row[1].toString()) ?? 0.0,
              "lng": double.tryParse(row[2].toString()) ?? 0.0,
              "street": "",
            };
          } catch (_) {
            return null;
          }
        })
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> _parseCSV(File file) async {
    final input = file.openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(const CsvToListConverter())
        .toList();
    return _parseCSVFields(fields);
  }

  Future<void> _processData(
      BuildContext context, List<Map<String, dynamic>> rawData) async {
    isImporting = true;
    totalImported = 0;
    totalRecords = 0;
    invalidRecords = 0;

    final Map<String, List<Map<String, dynamic>>> treesByArea = {};
    for (var area in areaNames) {
      treesByArea[area] = [];
    }

    for (var tree in rawData) {
      final lat = tree['lat'] as double;
      final lng = tree['lng'] as double;
      final area = getAreaForPoint(lat, lng);

      if (area != null && treesByArea.containsKey(area)) {
        try {
          final address = await _getAddressFromLatLng(lat, lng);
          tree['street'] = address;
          treesByArea[area]!.add(tree);
        } catch (e) {
          debugPrint('Geocoding failed for ($lat, $lng): $e');
          invalidRecords++;
        }
      } else {
        invalidRecords++;
      }
    }

    totalRecords = treesByArea.values.fold(0, (sum, list) => sum + list.length);

    if (totalRecords > 0) {
      await _uploadToFirestore(treesByArea);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Nhập thành công $totalRecords cây vào ${treesByArea.length} khu vực\n'
            '❌ Bỏ qua $invalidRecords cây (ngoài khu vực hoặc lỗi geocoding)',
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có dữ liệu nào nằm trong khu vực cho phép'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    isImporting = false;
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country
        ].where((part) => part?.isNotEmpty ?? false).join(', ');
      }
      return 'Không thể xác định địa chỉ';
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return 'Lỗi khi lấy địa chỉ';
    }
  }

  Future<void> _uploadToFirestore(
      Map<String, List<Map<String, dynamic>>> treesByArea) async {
    final adminTreesCollection =
        FirebaseFirestore.instance.collection("admin_tree");
    final batch = FirebaseFirestore.instance.batch();

    for (var entry in treesByArea.entries) {
      final areaName = entry.key;
      final trees = entry.value;

      if (trees.isNotEmpty) {
        final areaFeature = areaFeatures.firstWhere(
          (feature) => feature['name'] == areaName,
          orElse: () => {'properties': {}},
        );

        final cleanTrees = trees.map((tree) {
          final cleanTree = Map<String, dynamic>.from(tree);
          cleanTree.remove('created_at');
          return cleanTree;
        }).toList();

        final docRef = adminTreesCollection.doc("tree_$areaName");

        batch.set(docRef, {
          "area_name": areaName,
          "trees": cleanTrees,
          "count": cleanTrees.length,
          "properties": areaFeature['properties'],
          "created_at": FieldValue.serverTimestamp(),
          "updated_at": FieldValue.serverTimestamp(),
        });

        totalImported += cleanTrees.length;
      }
    }

    await batch.commit();
  }

  Future<void> requestPermissionsIfNeeded() async {
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      await Permission.storage.request();
    } else {
      await Permission.manageExternalStorage.request();
    }
  }
}
