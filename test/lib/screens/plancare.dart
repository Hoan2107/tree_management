import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class PlantHealthScreen extends StatefulWidget {
  const PlantHealthScreen({super.key});

  @override
  State<PlantHealthScreen> createState() => _PlantHealthScreenState();
}

class _PlantHealthScreenState extends State<PlantHealthScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<String, List<Map<String, dynamic>>> _healthData = {};
  List<Map<String, dynamic>> _todayHealthStatus = [];
  bool _isLoading = true;
  final _fabHeroTag = 'plantHealthFab';

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _loadHealthData();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getTreeHealthData() async {
    final result = <String, List<Map<String, dynamic>>>{
      'healthy': [],
      'sick': [],
      'dead': [],
    };

    try {
      final userTrees = await _firestore.collection('trees').get();
      for (var doc in userTrees.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

        if (status != null && timestamp != null && result.containsKey(status)) {
          result[status]?.add({
            ...data,
            'id': doc.id,
            'type': 'user_reported',
            'date': timestamp,
          });
        }
      }

      final adminTrees = await _firestore.collection('admin_tree').get();
      for (var doc in adminTrees.docs) {
        final data = doc.data();
        final trees = data['trees'] as List<dynamic>?;

        if (trees != null) {
          for (var tree in trees) {
            final status = tree['status'] as String?;
            final plantingDate = tree['plantingDate'] != null
                ? DateTime.parse(tree['plantingDate'])
                : null;

            if (status != null &&
                plantingDate != null &&
                result.containsKey(status)) {
              result[status]?.add({
                ...tree,
                'id': doc.id,
                'type': 'admin_managed',
                'date': plantingDate,
                'projectName': data['projectName'],
                'areaName': data['area_name'],
              });
            }
          }
        }
      }
    } catch (e) {
      _showSnackBar('Error loading tree health data: $e', Colors.red);
    }

    return result;
  }

  Future<void> _loadHealthData() async {
    setState(() => _isLoading = true);
    _healthData = await _getTreeHealthData();
    await _refreshHealthStatus();
    setState(() => _isLoading = false);
  }

  Future<void> _refreshHealthStatus() async {
    if (_selectedDay == null) return;

    setState(() {
      _todayHealthStatus = [];
    });

    final selectedDay = _selectedDay!;
    for (final status in _healthData.keys) {
      for (final tree in _healthData[status]!) {
        if (isSameDay(tree['date'] as DateTime, selectedDay)) {
          _todayHealthStatus.add({
            'status': status,
            ...tree,
          });
        }
      }
    }

    if (mounted) setState(() {});
  }

  void _jumpToDate(DateTime date) {
    setState(() {
      _focusedDay = date;
      _selectedDay = date;
    });
    _refreshHealthStatus();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Widget _buildDateMarker(BuildContext context, DateTime day, List events) {
    final sickTrees = _healthData['sick'] ?? [];
    final deadTrees = _healthData['dead'] ?? [];
    final healthyTrees = _healthData['healthy'] ?? [];

    final isSickDay = sickTrees.any((tree) => isSameDay(tree['date'], day));
    final isDeadDay = deadTrees.any((tree) => isSameDay(tree['date'], day));
    final isHealthyDay =
        healthyTrees.any((tree) => isSameDay(tree['date'], day));

    return Stack(
      children: [
        if (isSickDay)
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.orange[400],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
        if (isDeadDay)
          Positioned(
            left: 1,
            top: 1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
        if (isHealthyDay)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green[400],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHealthStatusItem(Map<String, dynamic> tree) {
    final status = tree['status'] as String;
    final date = tree['date'] as DateTime;
    final isAdminManaged = tree['type'] == 'admin_managed';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'sick':
        statusColor = Colors.orange;
        statusIcon = Icons.medical_services;
        statusText = 'Sick Tree';
        break;
      case 'dead':
        statusColor = Colors.grey;
        statusIcon = Icons.not_interested;
        statusText = 'Dead Tree';
        break;
      default:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Healthy Tree';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tree['name']?.toString() ?? 'Unknown Tree',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        'Type: ${tree['treeType']?.toString() ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Location: ${tree['street']?.toString() ?? 'Unknown'}',
              style: const TextStyle(fontSize: 14),
            ),
            if (isAdminManaged) ...[
              const SizedBox(height: 4),
              Text(
                'Project: ${tree['projectName']?.toString() ?? 'Unknown'}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Date: ${DateFormat('dd/MM/yyyy').format(date)}',
              style: const TextStyle(fontSize: 14),
            ),
            if (tree['lat'] != null && tree['lng'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Coordinates: (${tree['lat']?.toStringAsFixed(4)}, ${tree['lng']?.toStringAsFixed(4)})',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tree Health Calendar'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.medical_services, color: Colors.orange),
            tooltip: 'Sick Trees',
            onPressed: () {
              final sickTrees = _healthData['sick'];
              if (sickTrees != null && sickTrees.isNotEmpty) {
                _jumpToDate(sickTrees.first['date']);
              } else {
                _showSnackBar('No sick trees', Colors.orange);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.not_interested, color: Colors.grey),
            tooltip: 'Dead Trees',
            onPressed: () {
              final deadTrees = _healthData['dead'];
              if (deadTrees != null && deadTrees.isNotEmpty) {
                _jumpToDate(deadTrees.first['date']);
              } else {
                _showSnackBar('No dead trees', Colors.orange);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Healthy Trees',
            onPressed: () {
              final healthyTrees = _healthData['healthy'];
              if (healthyTrees != null && healthyTrees.isNotEmpty) {
                _jumpToDate(healthyTrees.first['date']);
              } else {
                _showSnackBar('No healthy trees', Colors.orange);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TableCalendar(
                    firstDay:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 730)),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (format) {
                      setState(() => _calendarFormat = format);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      _jumpToDate(selectedDay);
                    },
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: _buildDateMarker,
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      formatButtonDecoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      formatButtonTextStyle:
                          const TextStyle(color: Colors.white),
                      leftChevronIcon:
                          const Icon(Icons.chevron_left, color: Colors.green),
                      rightChevronIcon:
                          const Icon(Icons.chevron_right, color: Colors.green),
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.green[100],
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildLegendItem(Colors.green, 'Healthy'),
                      _buildLegendItem(Colors.orange, 'Sick'),
                      _buildLegendItem(Colors.grey, 'Dead'),
                    ],
                  ),
                ),
                const Divider(height: 20),
                Expanded(
                  child: _todayHealthStatus.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.nature,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No tree health records for this day',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Tree Health Status (${_todayHealthStatus.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._todayHealthStatus.map(_buildHealthStatusItem),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: _fabHeroTag,
        onPressed: () => _jumpToDate(DateTime.now()),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.today, color: Colors.white),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
