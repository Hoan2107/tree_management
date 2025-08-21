import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:diacritic/diacritic.dart';
import 'package:intl/intl.dart';

class BulkEditScreen extends StatefulWidget {
  const BulkEditScreen({super.key});

  @override
  State<BulkEditScreen> createState() => _BulkEditScreenState();
}

class _BulkEditScreenState extends State<BulkEditScreen> {
  Map<String, Map<String, List<Map<String, dynamic>>>> groupedByAreaAndName =
      {};
  bool isLoading = true;
  String? selectedArea;
  String? selectedName;
  final _formKey = GlobalKey<FormState>();
  String? updatedStreet;
  String? updatedTreeType;
  String? updatedStatus;
  DateTime? updatedPlantingDate;

  @override
  void initState() {
    super.initState();
    _loadAdminTrees();
  }

  Future<void> _loadAdminTrees() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('admin_tree').get();
    final Map<String, Map<String, List<Map<String, dynamic>>>> result = {};

    for (var doc in snapshot.docs) {
      final area = doc['area_name']?.toString() ?? 'Không rõ';
      final docId = doc.id;
      final List<dynamic> trees = doc['trees'] ?? [];

      for (var tree in trees) {
        final name = tree['name']?.toString() ?? '';
        result[area] ??= {};
        result[area]![name] ??= [];
        result[area]![name]!.add({
          ...tree,
          'docId': docId,
        });
      }
    }

    setState(() {
      groupedByAreaAndName = result;
      isLoading = false;
    });
  }

  void _updateSelectedGroup() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final group = groupedByAreaAndName[selectedArea]?[selectedName!];
    if (group == null) return;

    final byDoc = groupBy(group, (tree) => tree['docId']);

    for (var entry in byDoc.entries) {
      final docId = entry.key;
      final docRef =
          FirebaseFirestore.instance.collection('admin_tree').doc(docId);
      final docSnap = await docRef.get();
      final List<dynamic> currentTrees = List.from(docSnap['trees'] ?? []);

      final updatedTrees = currentTrees.map((tree) {
        final areaMatch = docSnap['area_name']?.toString() == selectedArea;
        final nameMatch = (tree['name'] ?? '') == selectedName;
        if (areaMatch && nameMatch) {
          return {
            ...tree,
            if (updatedStreet != null) 'street': updatedStreet,
            if (updatedTreeType != null) 'treeType': updatedTreeType,
            if (updatedStatus != null) 'status': updatedStatus,
            if (updatedPlantingDate != null)
              'plantingDate':
                  DateFormat('yyyy-MM-dd').format(updatedPlantingDate!),
          };
        }
        return tree;
      }).toList();

      await docRef.update({
        'trees': updatedTrees,
        'count': updatedTrees.length,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật tất cả các cây thành công'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      selectedArea = null;
      selectedName = null;
      updatedStreet = null;
      updatedTreeType = null;
      updatedStatus = null;
      updatedPlantingDate = null;
    });

    _loadAdminTrees();
  }

  void _deleteSelectedGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa', style: TextStyle(color: Colors.red)),
        content: Text(
            'Bạn có chắc muốn xóa tất cả cây có tên "$selectedName" trong khu vực "$selectedArea"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    if (confirm != true) return;

    final group = groupedByAreaAndName[selectedArea]?[selectedName!];
    if (group == null) return;

    final byDoc = groupBy(group, (tree) => tree['docId']);

    for (var entry in byDoc.entries) {
      final docId = entry.key;
      final docRef =
          FirebaseFirestore.instance.collection('admin_tree').doc(docId);
      final docSnap = await docRef.get();
      final List<dynamic> currentTrees = List.from(docSnap['trees'] ?? []);

      final updatedTrees = currentTrees.where((tree) {
        return tree['name'] != selectedName;
      }).toList();

      await docRef.update({
        'trees': updatedTrees,
        'count': updatedTrees.length,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã xóa tất cả các cây thành công'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      selectedArea = null;
      selectedName = null;
    });

    _loadAdminTrees();
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        updatedPlantingDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final areaList = groupedByAreaAndName.keys.toList()..sort();
    List<String> nameList = [];

    if (selectedArea != null && groupedByAreaAndName[selectedArea] != null) {
      nameList = groupedByAreaAndName[selectedArea]!.keys.toList();
      nameList.sort((a, b) => a.compareTo(b));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hàng loạt theo tên & khu vực',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[800],
        elevation: 4,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đang tải dữ liệu...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Chọn nhóm cây cần chỉnh sửa',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Khu vực',
                              labelStyle: const TextStyle(color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Colors.green),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Colors.green),
                              ),
                              filled: true,
                              fillColor: Colors.green[50],
                              prefixIcon: const Icon(Icons.location_on,
                                  color: Colors.green),
                            ),
                            value: selectedArea,
                            items: areaList
                                .map((area) => DropdownMenuItem(
                                      value: area,
                                      child: Text(
                                        area,
                                        style: const TextStyle(
                                            color: Colors.black87),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                selectedArea = val;
                                selectedName = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Colors.green[50],
                          ),
                          const SizedBox(height: 16),
                          if (selectedArea != null)
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Tên cây',
                                labelStyle:
                                    const TextStyle(color: Colors.green),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: Colors.green),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: Colors.green),
                                ),
                                filled: true,
                                fillColor: Colors.green[50],
                                prefixIcon: const Icon(Icons.nature,
                                    color: Colors.green),
                              ),
                              value: selectedName,
                              items: nameList
                                  .map((name) => DropdownMenuItem(
                                        value: name,
                                        child: RichText(
                                          text: TextSpan(
                                            text: name,
                                            style: const TextStyle(
                                                color: Colors.black87),
                                            children: [
                                              TextSpan(
                                                text:
                                                    ' (${groupedByAreaAndName[selectedArea]![name]!.length} cây)',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedName = val;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              dropdownColor: Colors.green[50],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (selectedName != null)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Cập nhật thông tin cho ${groupedByAreaAndName[selectedArea]![selectedName]!.length} cây',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.green[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Đường',
                                  labelStyle:
                                      const TextStyle(color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: Colors.green),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: Colors.green),
                                  ),
                                  filled: true,
                                  fillColor: Colors.green[50],
                                  prefixIcon: const Icon(Icons.route,
                                      color: Colors.green),
                                ),
                                onSaved: (val) => updatedStreet = val?.trim(),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Loại cây',
                                  labelStyle:
                                      const TextStyle(color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: Colors.green),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: Colors.green),
                                  ),
                                  filled: true,
                                  fillColor: Colors.green[50],
                                  prefixIcon: const Icon(Icons.park,
                                      color: Colors.green),
                                ),
                                onSaved: (val) => updatedTreeType = val?.trim(),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Tình trạng',
                                  labelStyle:
                                      const TextStyle(color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: Colors.green),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: Colors.green),
                                  ),
                                  filled: true,
                                  fillColor: Colors.green[50],
                                  prefixIcon: const Icon(
                                      Icons.health_and_safety,
                                      color: Colors.green),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'healthy',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('Khỏe mạnh'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'sick',
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning,
                                            color: Colors.orange),
                                        SizedBox(width: 8),
                                        Text('Bị bệnh'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'dead',
                                    child: Row(
                                      children: [
                                        Icon(Icons.dangerous,
                                            color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Đã chết'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (val) => updatedStatus = val,
                                borderRadius: BorderRadius.circular(12),
                                dropdownColor: Colors.green[50],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        color: Colors.green),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Ngày trồng: ',
                                      style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 16),
                                    ),
                                    const Spacer(),
                                    Text(
                                      updatedPlantingDate == null
                                          ? 'Chưa chọn'
                                          : DateFormat('dd/MM/yyyy')
                                              .format(updatedPlantingDate!),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(
                                      onPressed: () => _pickDate(context),
                                      child: const Text('Chọn',
                                          style:
                                              TextStyle(color: Colors.green)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _updateSelectedGroup,
                                      icon: const Icon(Icons.save),
                                      label: const Text('CẬP NHẬT TẤT CẢ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _deleteSelectedGroup,
                                      icon: const Icon(Icons.delete),
                                      label: const Text('XÓA TẤT CẢ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[400],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    selectedName = null;
                                  });
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_back, size: 18),
                                    SizedBox(width: 8),
                                    Text('Quay lại chọn tên cây'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
