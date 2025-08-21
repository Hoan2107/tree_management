import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'map_view_screen.dart'; // Import file mapview.dart

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;
  String _selectedMapType = "OSM";
  List<Marker> _treeMarkers = [];
  LatLng? _selectedAreaStart;
  LatLng? _selectedAreaEnd;
  int _treeCountInArea = 0;
  final List<Map<String, dynamic>> _treesInArea = [];
  double _areaSize = 0.0; // Diện tích khu vực (km²)
  int _treesToPlant = 0; // Số cây cần trồng thêm

  final List<Map<String, String>> _mapTypes = [
    {"name": "OSM", "url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png"},
    {
      "name": "Google Satellite",
      "url": "https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}"
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchTreesFromFirestore();
  }

  void _changeMapType(String newType) {
    setState(() {
      _selectedMapType = newType;
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await Permission.storage.request();
    } else {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _fetchTreesFromFirestore() async {
    FirebaseFirestore.instance
        .collection('admin_tree')
        .get()
        .then((querySnapshot) {
      List<Marker> markers = [];
      for (var doc in querySnapshot.docs) {
        var data = doc.data();
        if (data.containsKey('trees')) {
          for (var tree in data['trees']) {
            markers.add(
              Marker(
                width: 40,
                height: 40,
                point: LatLng(tree['lat'], tree['lng']),
                child: const Icon(
                  Icons.nature,
                  color: Colors.green,
                  size: 30,
                ),
              ),
            );
          }
        }
      }
      setState(() {
        _treeMarkers = markers;
      });
    });
  }

  Future<void> _importCSV() async {
    try {
      await _requestPermissions();
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(CsvToListConverter())
            .toList();

        List<Map<String, dynamic>> treesData = [];
        for (var i = 1; i < fields.length; i++) {
          treesData.add({
            "name": fields[i][0],
            "lat": fields[i][1],
            "lng": fields[i][2],
            "street": fields[i][3],
          });
        }

        await _uploadToFirestore(treesData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV imported successfully!')),
        );
      }
    } catch (e) {
      debugPrint("❌ Lỗi khi chọn file CSV: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import CSV: $e')),
      );
    }
  }

  Future<void> _uploadToFirestore(List<Map<String, dynamic>> treesData) async {
    Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var tree in treesData) {
      String street = tree["street"];
      if (!groupedData.containsKey(street)) {
        groupedData[street] = [];
      }
      groupedData[street]!.add(tree);
    }
    for (var entry in groupedData.entries) {
      await FirebaseFirestore.instance
          .collection("admin_tree")
          .doc(entry.key)
          .set({
        "name": entry.key,
        "trees": entry.value,
      });
    }
    _fetchTreesFromFirestore();
  }

  // Tính diện tích sử dụng công thức Haversine
  double _calculateArea(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Bán kính Trái Đất (km)
    double lat1 = point1.latitude * pi / 180;
    double lat2 = point2.latitude * pi / 180;
    double lng1 = point1.longitude * pi / 180;
    double lng2 = point2.longitude * pi / 180;

    double dLat = lat2 - lat1;
    double dLng = lng2 - lng1;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Diện tích (km²)
  }

  void _calculateTreeDensityInArea() {
    if (_selectedAreaStart == null || _selectedAreaEnd == null) return;

    // Tính diện tích khu vực
    _areaSize = _calculateArea(_selectedAreaStart!, _selectedAreaEnd!);

    // Tính số cây cần trồng thêm (giả sử mật độ tiêu chuẩn là 100 cây/km²)
    const standardDensity = 100; // Cây/km²
    _treesToPlant = (_areaSize * standardDensity).round() - _treeCountInArea;

    // Lọc cây trong khu vực
    _treesInArea.clear();
    for (var marker in _treeMarkers) {
      if (marker.point.latitude >= _selectedAreaStart!.latitude &&
          marker.point.latitude <= _selectedAreaEnd!.latitude &&
          marker.point.longitude >= _selectedAreaStart!.longitude &&
          marker.point.longitude <= _selectedAreaEnd!.longitude) {
        _treesInArea.add({
          "lat": marker.point.latitude,
          "lng": marker.point.longitude,
        });
      }
    }
    setState(() {
      _treeCountInArea = _treesInArea.length;
    });
  }

  void _resetAreaSelection() {
    setState(() {
      _selectedAreaStart = null;
      _selectedAreaEnd = null;
      _treeCountInArea = 0;
      _treesInArea.clear();
      _areaSize = 0.0;
      _treesToPlant = 0;
    });
  }

  void _showAreaOptions(BuildContext context, LatLng point) {
    if (_selectedAreaStart != null && _selectedAreaEnd != null) {
      _calculateTreeDensityInArea();
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Thông tin khu vực",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.nature),
                  title: const Text("Số cây trong khu vực"),
                  subtitle: Text("$_treeCountInArea cây"),
                ),
                ListTile(
                  leading: const Icon(Icons.forest),
                  title: const Text("Số cây cần trồng thêm"),
                  subtitle: Text("$_treesToPlant cây"),
                ),
                ListTile(
                  leading: const Icon(Icons.area_chart),
                  title: const Text("Diện tích khu vực"),
                  subtitle: Text("${_areaSize.toStringAsFixed(2)} km²"),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _resetAreaSelection,
                  child: const Text("Reset khu vực"),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildMapScreen() {
    return Stack(
      children: [
        MapViewScreen(), // Sử dụng MapViewScreen từ file mapview.dart
        Positioned(
          top: 10,
          left: 10, // Chuyển nút chuyển đổi sang bên trái
          child: _buildMapSwitcher(),
        ),
      ],
    );
  }

  Widget _buildMapSwitcher() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)
        ],
      ),
      child: Column(
        children: _mapTypes.map((mapType) {
          return GestureDetector(
            onTap: () => _changeMapType(mapType["name"]!),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
              decoration: BoxDecoration(
                color: _selectedMapType == mapType["name"]
                    ? Colors.blueAccent
                    : Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                mapType["name"]!,
                style: TextStyle(
                  color: _selectedMapType == mapType["name"]
                      ? Colors.white
                      : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImportScreen() {
    return Center(
      child: ElevatedButton(
        onPressed: _importCSV,
        child: const Text("Chọn file CSV"),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text("Admin Panel")),
      body: _selectedIndex == 0 ? _buildMapScreen() : _buildImportScreen(),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.upload_file), label: 'Import'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}
