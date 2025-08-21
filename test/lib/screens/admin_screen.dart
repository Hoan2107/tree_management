import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'map_view_screen.dart';
import 'administrators.dart';
import 'plancare.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'importcsv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'dart:html' as html;
import 'package:path_provider/path_provider.dart';
import 'bulk_edit_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;
  int totalTrees = 0;
  int totalAreas = 0;
  double totalAreaKm2 = 0;
  double avgDensity = 0;
  bool isLoadingStats = true;
  List<AreaStat> areaStats = [];
  String? selectedArea;
  List<TreeData> recentTrees = [];
  PlatformFile? _selectedFile;
  bool _isImporting = false;
  int _totalImported = 0;
  int _totalRecords = 0;
  int _invalidRecords = 0;
  final CsvImporter _csvImporter = CsvImporter();

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
    _fetchRecentTrees();
    _csvImporter.loadGeoJson();
  }

  Future<void> _fetchStatistics() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('admin_tree')
          .orderBy('created_at', descending: true)
          .get();

      int trees = 0;
      int areas = querySnapshot.docs.length;
      double areaKm2 = 0;
      final List<AreaStat> stats = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final int count = data['count'] ?? 0;
        final double area = (data['properties']?['area_km2'] ?? 1).toDouble();
        final String areaName = data['area_name'] ?? 'Khu vực ${doc.id}';
        final String contractor = data['contractorName'] ?? 'Chưa xác định';
        final String project = data['projectName'] ?? 'Không có dự án';
        final String street =
            data['properties']?['street'] ?? 'Không có thông tin';

        trees += count;
        areaKm2 += area;

        stats.add(AreaStat(
          name: areaName,
          treeCount: count,
          area: area,
          density: count / area,
          contractor: contractor,
          project: project,
          street: street,
        ));
      }

      setState(() {
        totalTrees = trees;
        totalAreas = areas;
        totalAreaKm2 = areaKm2;
        avgDensity = areaKm2 > 0 ? trees / areaKm2 : 0;
        areaStats = stats;
        isLoadingStats = false;
      });
    } catch (e) {
      setState(() => isLoadingStats = false);
      _showErrorSnackbar('Lỗi khi tải dữ liệu: ${e.toString()}');
    }
  }

  Future<void> _fetchRecentTrees() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('admin_tree')
          .orderBy('created_at', descending: true)
          .limit(5)
          .get();

      List<TreeData> trees = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final treeList = data['trees'] as List<dynamic>? ?? [];

        for (var tree in treeList) {
          trees.add(TreeData(
            name: tree['name'] ?? 'Không tên',
            type: tree['treeType'] ?? 'Không xác định',
            lat: tree['lat']?.toDouble() ?? 0,
            lng: tree['lng']?.toDouble() ?? 0,
            street: tree['street'] ?? 'Không có thông tin',
            area: data['area_name'] ?? 'Không xác định',
            date: data['created_at']?.toDate() ?? DateTime.now(),
          ));
        }
      }

      setState(() {
        recentTrees = trees;
      });
    } catch (e) {
      _showErrorSnackbar('Lỗi khi tải cây mới: ${e.toString()}');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
          _isImporting = false;
          _totalImported = 0;
          _totalRecords = 0;
          _invalidRecords = 0;
        });
      }
    } catch (e) {
      _showErrorSnackbar('Lỗi khi chọn file: ${e.toString()}');
    }
  }

  Future<void> _importData() async {
    if (_selectedFile == null) return;

    setState(() {
      _isImporting = true;
    });

    try {
      if (kIsWeb) {
        final content = utf8.decode(_selectedFile!.bytes!);
        await _csvImporter.importCSVFromContent(context, content);
      } else {
        final file = File(_selectedFile!.path!);
        await _csvImporter.importCSVFromFile(context, file);
      }

      setState(() {
        _totalImported = _csvImporter.totalImported;
        _totalRecords = _csvImporter.totalRecords;
        _invalidRecords = _csvImporter.invalidRecords;
      });

      _fetchStatistics();
      _fetchRecentTrees();
    } catch (e) {
      _showErrorSnackbar('Lỗi khi nhập liệu: ${e.toString()}');
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      const csvData = '''name,lat,lng,street
Cây Xoai,10.762622,106.660172,Duong Nguyen Van Linh
Cây Bang,10.763456,106.661234,Duong Nguyen Van Linh
Cây Phuong,10.764321,106.662345,Duong Nguyen Van Linh''';

      if (kIsWeb) {
        final bytes = utf8.encode(csvData);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..download = 'mau_cay_xanh.csv'
          ..style.display = 'none';

        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        _showSuccessSnackbar('Đã bắt đầu tải xuống file mẫu');
      } else {
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          final filePath = path.join(directory.path, 'mau_cay_xanh.csv');
          final file = File(filePath);
          await file.writeAsString(csvData);
          _showSuccessSnackbar('Đã tải xuống file mẫu tại: $filePath');
        } else {
          _showErrorSnackbar('Không thể xác định thư mục tải xuống');
        }
      }
    } catch (e) {
      _showErrorSnackbar('Lỗi khi tải file mẫu: ${e.toString()}');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HỆ THỐNG QUẢN LÝ CÂY XANH',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoadingStats = true;
              });
              _fetchStatistics();
              _fetchRecentTrees();
            },
          ),
        ],
      ),
      drawer: MediaQuery.of(context).size.width <= 800 ? _buildSidebar() : null,
      body: Row(
        children: [
          if (MediaQuery.of(context).size.width > 800) _buildSidebar(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboardScreen(),
                _buildImportScreen(),
                const AdministratorsScreen(),
                const PlantHealthScreen(),
                const MapViewScreen(interactive: true),
                const BulkEditScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 280,
      child: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: Colors.green[800],
                      image: const DecorationImage(
                        image: AssetImage('assets/tree_bg.png'),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black54,
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.eco, size: 40, color: Colors.white),
                        SizedBox(height: 10),
                        Text(
                          'QUẢN LÝ CÂY XANH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildNavItem(
                    icon: Icons.dashboard,
                    label: "Tổng quan",
                    isActive: _selectedIndex == 0,
                    onTap: () => _onItemTapped(0),
                  ),
                  _buildNavItem(
                    icon: Icons.map,
                    label: "Bản đồ",
                    isActive: _selectedIndex == 4,
                    onTap: () => _onItemTapped(4),
                  ),
                  _buildNavItem(
                    icon: Icons.cloud_upload,
                    label: "Nhập liệu",
                    isActive: _selectedIndex == 1,
                    onTap: () => _onItemTapped(1),
                  ),
                  _buildNavItem(
                    icon: Icons.people,
                    label: "Quản lý",
                    isActive: _selectedIndex == 2,
                    onTap: () => _onItemTapped(2),
                  ),
                  _buildNavItem(
                    icon: Icons.calendar_today,
                    label: "Chăm sóc",
                    isActive: _selectedIndex == 3,
                    onTap: () => _onItemTapped(3),
                  ),
                  _buildNavItem(
                    icon: Icons.edit,
                    label: "Chỉnh sửa hàng loạt",
                    isActive: _selectedIndex == 5,
                    onTap: () => _onItemTapped(5),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'KHU VỰC',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (isLoadingStats)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    )
                  else
                    ...areaStats.map((area) => _buildAreaFilterItem(area)),
                ],
              ),
            ),
            _buildVersionInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Phiên bản 1.0.0',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isActive ? Colors.green[800] : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.green[800] : Colors.black87,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      selectedTileColor: Colors.green[50],
      onTap: onTap,
    );
  }

  Widget _buildAreaFilterItem(AreaStat area) {
    return ListTile(
      title: Text(
        area.name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text('${area.treeCount} cây - ${area.street}'),
      trailing: Chip(
        label: Text('${area.density.toStringAsFixed(1)}/km²'),
        backgroundColor: Colors.green[50],
      ),
      onTap: () {
        setState(() {
          selectedArea = selectedArea == area.name ? null : area.name;
        });
      },
      selected: selectedArea == area.name,
      selectedTileColor: Colors.green[50],
    );
  }

  Widget _buildDashboardScreen() {
    final filteredStats = selectedArea != null
        ? areaStats.where((a) => a.name == selectedArea).toList()
        : areaStats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedArea != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Chip(
                label: Text(
                  'Đang xem: $selectedArea',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.green[800],
                deleteIcon:
                    const Icon(Icons.close, size: 18, color: Colors.white),
                onDeleted: () {
                  setState(() {
                    selectedArea = null;
                  });
                },
              ),
            ),
          _buildSummarySection(),
          const SizedBox(height: 16),
          _buildMapSection(),
          const SizedBox(height: 16),
          _buildRecentTreesSection(),
          const SizedBox(height: 16),
          _buildDensitySection(filteredStats),
          const SizedBox(height: 16),
          _buildAreaDetailsSection(filteredStats),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'THỐNG KÊ TỔNG QUAN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildSummaryCard(
                  title: 'TỔNG SỐ CÂY',
                  value: totalTrees.toString(),
                  icon: Icons.park,
                  color: Colors.green[800]!,
                ),
                _buildSummaryCard(
                  title: 'SỐ KHU VỰC',
                  value: totalAreas.toString(),
                  icon: Icons.location_city,
                  color: Colors.blue[800]!,
                ),
                _buildSummaryCard(
                  title: 'DIỆN TÍCH',
                  value: '${totalAreaKm2.toStringAsFixed(2)} km²',
                  icon: Icons.area_chart,
                  color: Colors.orange[800]!,
                ),
                _buildSummaryCard(
                  title: 'MẬT ĐỘ TB',
                  value: '${avgDensity.toStringAsFixed(1)} cây/km²',
                  icon: Icons.density_medium,
                  color: Colors.purple[800]!,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 250,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: const SizedBox(
        height: 400,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          child: MapViewScreen(interactive: true),
        ),
      ),
    );
  }

  Widget _buildRecentTreesSection() {
    if (recentTrees.isEmpty) return const SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CÂY MỚI ĐƯỢC THÊM GẦN ĐÂY',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentTrees.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final tree = recentTrees[index];
                  return Container(
                    width: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.park, color: Colors.green[800]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tree.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTreeDetailRow('Loại', tree.type),
                          _buildTreeDetailRow('Khu vực', tree.area),
                          _buildTreeDetailRow('Đường', tree.street),
                          const Spacer(),
                          Text(
                            'Thêm ngày: ${DateFormat('dd/MM/yyyy').format(tree.date)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDensitySection(List<AreaStat> stats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MẬT ĐỘ CÂY THEO KHU VỰC',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 500,
              child: SfCartesianChart(
                margin: const EdgeInsets.all(0),
                primaryXAxis: CategoryAxis(
                  labelRotation: 0,
                  labelStyle: const TextStyle(fontSize: 10),
                  labelIntersectAction: AxisLabelIntersectAction.wrap,
                  maximumLabels: 100,
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLabelFormatter: (axisLabelRenderArgs) {
                    return ChartAxisLabel(
                      axisLabelRenderArgs.text,
                      const TextStyle(fontSize: 10),
                    );
                  },
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Cây/km²'),
                  majorGridLines: const MajorGridLines(width: 0.5),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                zoomPanBehavior: ZoomPanBehavior(
                  enablePinching: true,
                  enableDoubleTapZooming: true,
                  enablePanning: true,
                ),
                series: <CartesianSeries>[
                  BarSeries<AreaStat, String>(
                    dataSource: stats,
                    xValueMapper: (AreaStat data, _) => data.name,
                    yValueMapper: (AreaStat data, _) => data.density,
                    color: Colors.green,
                    name: 'Mật độ',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.top,
                      textStyle: TextStyle(fontSize: 10),
                    ),
                    width: 0.6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaDetailsSection(List<AreaStat> stats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CHI TIẾT KHU VỰC',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 12,
                headingRowHeight: 40,
                dataRowHeight: 40,
                columns: const [
                  DataColumn(
                      label: Text('Khu vực',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Số cây',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Diện tích (km²)',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Mật độ',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Nhà thầu',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Dự án',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Đường',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: stats
                    .map((area) => DataRow(
                          cells: [
                            DataCell(SizedBox(
                              width: 150,
                              child: Text(
                                area.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                            DataCell(
                                Center(child: Text(area.treeCount.toString()))),
                            DataCell(Center(
                                child: Text(area.area.toStringAsFixed(2)))),
                            DataCell(Center(
                                child: Text(
                                    '${area.density.toStringAsFixed(1)}/km²'))),
                            DataCell(SizedBox(
                              width: 120,
                              child: Text(
                                area.contractor,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                            DataCell(SizedBox(
                              width: 120,
                              child: Text(
                                area.project,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                            DataCell(SizedBox(
                              width: 120,
                              child: Text(
                                area.street,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                          ],
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildImportCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCard() {
    return SizedBox(
      width: 600,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[800],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'NHẬP DỮ LIỆU CÂY XANH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tải lên file CSV từ hệ thống',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 64,
                    color: Colors.green[400],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Kéo thả file CSV vào đây hoặc",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      icon: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload, size: 16),
                      label: Text(_isImporting ? "Đang xử lý..." : "Chọn file"),
                      onPressed: _isImporting ? null : _pickFile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green[800],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedFile != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file,
                              color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFile!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                _selectedFile = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isImporting) ...[
                      LinearProgressIndicator(
                        value: _totalRecords > 0
                            ? _totalImported / _totalRecords
                            : null,
                        backgroundColor: Colors.grey[200],
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đang xử lý: $_totalImported/$_totalRecords (Bỏ qua $_invalidRecords)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isImporting ? null : _importData,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.green[800],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('BẮT ĐẦU NHẬP LIỆU'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ĐỊNH DẠNG FILE YÊU CẦU",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Tên, Vĩ độ, Kinh độ, Đường phố",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _downloadTemplate,
                    child: const Text('Tải về file mẫu'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Bản đồ toàn màn hình'),
              backgroundColor: Colors.green[800],
              foregroundColor: Colors.white,
            ),
            body: const MapViewScreen(interactive: true),
          ),
        ),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  }
}

class AreaStat {
  final String name;
  final int treeCount;
  final double area;
  final double density;
  final String contractor;
  final String project;
  final String street;

  AreaStat({
    required this.name,
    required this.treeCount,
    required this.area,
    required this.density,
    required this.contractor,
    required this.project,
    required this.street,
  });
}

class TreeData {
  final String name;
  final String type;
  final double lat;
  final double lng;
  final String street;
  final String area;
  final DateTime date;

  TreeData({
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.street,
    required this.area,
    required this.date,
  });
}
