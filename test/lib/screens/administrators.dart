import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdministratorsScreen extends StatefulWidget {
  const AdministratorsScreen({super.key});

  @override
  State<AdministratorsScreen> createState() => _AdministratorsScreenState();
}

class _AdministratorsScreenState extends State<AdministratorsScreen> {
  List<DocumentSnapshot> _projects = [];
  bool isLoading = true;
  final _formKey = GlobalKey<FormState>();
  final _editFormKey = GlobalKey<FormState>();

  String? _projectName;
  String? _contractorName;
  String? _phone;
  DateTime? _startDate;
  String? _treeType;
  int? _treeCount;
  String? _selectedArea;

  String? _editProjectName;
  String? _editContractorName;
  String? _editPhone;
  DateTime? _editStartDate;
  String? _editTreeType;
  int? _editTreeCount;
  String? _editSelectedArea;

  List<String> _availableAreas = [];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchAreas();
  }

  Future<void> _fetchProjects() async {
    setState(() => isLoading = true);
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('admin_tree')
          .where('projectName', isNotEqualTo: null)
          .get();
      setState(() {
        _projects = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      _showSnackBar("Lỗi tải dữ liệu dự án: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _fetchAreas() async {
    try {
      QuerySnapshot areaSnapshot = await FirebaseFirestore.instance
          .collection('admin_tree')
          .where('area_name', isNotEqualTo: null)
          .get();

      final areas = areaSnapshot.docs
          .map((doc) => doc['area_name'] as String?)
          .where((area) => area != null)
          .cast<String>();
      setState(() {
        _availableAreas = areas.toSet().toList();
      });
    } catch (e) {
      _showSnackBar("Lỗi tải khu vực: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _addProject() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      await FirebaseFirestore.instance.collection('admin_tree').add({
        'projectName': _projectName,
        'contractorName': _contractorName,
        'phone': _phone,
        'startDate': _startDate?.toIso8601String(),
        'treeType': _treeType,
        'count': _treeCount ?? 0,
        'area_name': _selectedArea,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      _fetchProjects();
      Navigator.pop(context);
      _showSnackBar("Thêm dự án thành công", Colors.green);
    } catch (e) {
      _showSnackBar("Lỗi thêm dự án: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _updateProject(String id) async {
    if (!_editFormKey.currentState!.validate()) return;
    _editFormKey.currentState!.save();

    try {
      await FirebaseFirestore.instance.collection('admin_tree').doc(id).update({
        'projectName': _editProjectName,
        'contractorName': _editContractorName,
        'phone': _editPhone,
        'startDate': _editStartDate?.toIso8601String(),
        'treeType': _editTreeType,
        'count': _editTreeCount ?? 0,
        'area_name': _editSelectedArea,
        'updated_at': FieldValue.serverTimestamp(),
      });
      _fetchProjects();
      Navigator.pop(context);
      _showSnackBar("Cập nhật dự án thành công", Colors.green);
    } catch (e) {
      _showSnackBar("Lỗi cập nhật dự án: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _deleteProject(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_tree')
          .doc(id)
          .delete();
      _fetchProjects();
      _showSnackBar("Đã xóa dự án", Colors.green);
    } catch (e) {
      _showSnackBar("Lỗi khi xóa: ${e.toString()}", Colors.red);
    }
  }

  void _showAddProjectDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Thêm dự án mới",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        label: 'Tên dự án',
                        validator: (val) => val!.isEmpty ? 'Bắt buộc' : null,
                        onSaved: (val) => _projectName = val,
                      ),
                      _buildTextField(
                        label: 'Chủ thầu',
                        validator: (val) => val!.isEmpty ? 'Bắt buộc' : null,
                        onSaved: (val) => _contractorName = val,
                      ),
                      _buildTextField(
                        label: 'Số điện thoại',
                        keyboardType: TextInputType.phone,
                        validator: (val) =>
                            val!.length != 10 ? 'SĐT không hợp lệ' : null,
                        onSaved: (val) => _phone = val,
                      ),
                      _buildTextField(
                        label: 'Loại cây',
                        onSaved: (val) => _treeType = val,
                      ),
                      _buildTextField(
                        label: 'Số lượng cây',
                        keyboardType: TextInputType.number,
                        validator: (val) =>
                            int.tryParse(val!) == null ? 'Phải là số' : null,
                        onSaved: (val) => _treeCount = int.tryParse(val!),
                      ),
                      const SizedBox(height: 8),
                      _buildDropdownButton(),
                      const SizedBox(height: 12),
                      _buildDatePickerButton(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Hủy",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _addProject,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Lưu",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String? initialValue,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        keyboardType: keyboardType,
        validator: validator,
        onSaved: onSaved,
      ),
    );
  }

  Widget _buildDropdownButton() {
    return DropdownButtonFormField<String>(
      value: _selectedArea,
      items: _availableAreas
          .map((area) => DropdownMenuItem(
                value: area,
                child: Text(area),
              ))
          .toList(),
      onChanged: (val) => setState(() => _selectedArea = val),
      decoration: InputDecoration(
        labelText: "Khu vực",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      validator: (val) => val == null ? 'Bắt buộc' : null,
    );
  }

  Widget _buildDatePickerButton() {
    return ElevatedButton(
      onPressed: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
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
          setState(() => _startDate = picked);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.green),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(
            _startDate == null
                ? 'Chọn ngày bắt đầu'
                : 'Ngày bắt đầu: ${DateFormat('dd/MM/yyyy').format(_startDate!)}',
            style: const TextStyle(color: Colors.green),
          ),
        ],
      ),
    );
  }

  void _showProjectDetails(DocumentSnapshot project) {
    final data = project.data() as Map<String, dynamic>? ?? {};

    _editProjectName = data['projectName'];
    _editContractorName = data['contractorName'];
    _editPhone = data['phone'];
    _editTreeType = data['treeType'];
    _editTreeCount = data['count'] ?? 0;
    _editSelectedArea = data['area_name'];

    // Sửa lỗi định dạng ngày tháng
    if (data['startDate'] != null) {
      try {
        // Thử parse theo ISO 8601
        _editStartDate = DateTime.parse(data['startDate']);
      } catch (e) {
        // Nếu không được, thử parse theo các định dạng khác
        try {
          // Thử parse theo định dạng MM/dd/yyyy
          List<String> dateParts = data['startDate'].split('/');
          if (dateParts.length == 3) {
            _editStartDate = DateTime(int.parse(dateParts[2]),
                int.parse(dateParts[0]), int.parse(dateParts[1]));
          }
        } catch (e) {
          // Nếu vẫn lỗi, set thành null
          _editStartDate = null;
        }
      }
    } else {
      _editStartDate = null;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Chi tiết dự án",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailItem(
                  icon: Icons.assignment,
                  title: "Tên dự án",
                  value: data['projectName'] ?? 'Chưa đặt tên',
                ),
                _buildDetailItem(
                  icon: Icons.person,
                  title: "Chủ thầu",
                  value: data['contractorName'] ?? 'Không rõ',
                ),
                _buildDetailItem(
                  icon: Icons.phone,
                  title: "Số điện thoại",
                  value: data['phone'] ?? 'Không có',
                ),
                _buildDetailItem(
                  icon: Icons.location_on,
                  title: "Khu vực",
                  value: data['area_name'] ?? 'Không xác định',
                ),
                _buildDetailItem(
                  icon: Icons.nature,
                  title: "Loại cây",
                  value: data['treeType'] ?? 'Không rõ',
                ),
                _buildDetailItem(
                  icon: Icons.format_list_numbered,
                  title: "Số lượng cây",
                  value: (data['count'] ?? 0).toString(),
                ),
                _buildDetailItem(
                  icon: Icons.calendar_today,
                  title: "Ngày bắt đầu",
                  value: _editStartDate != null
                      ? DateFormat('dd/MM/yyyy').format(_editStartDate!)
                      : 'Không rõ',
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.edit,
                      label: "Sửa",
                      color: Colors.blue,
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditProjectDialog(project);
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.delete,
                      label: "Xóa",
                      color: Colors.red,
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDeleteProject(project.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  void _showEditProjectDialog(DocumentSnapshot project) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Chỉnh sửa dự án",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _editFormKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        label: 'Tên dự án',
                        initialValue: _editProjectName,
                        validator: (val) => val!.isEmpty ? 'Bắt buộc' : null,
                        onSaved: (val) => _editProjectName = val,
                      ),
                      _buildTextField(
                        label: 'Chủ thầu',
                        initialValue: _editContractorName,
                        validator: (val) => val!.isEmpty ? 'Bắt buộc' : null,
                        onSaved: (val) => _editContractorName = val,
                      ),
                      _buildTextField(
                        label: 'Số điện thoại',
                        initialValue: _editPhone,
                        keyboardType: TextInputType.phone,
                        validator: (val) =>
                            val!.length != 10 ? 'SĐT không hợp lệ' : null,
                        onSaved: (val) => _editPhone = val,
                      ),
                      _buildTextField(
                        label: 'Loại cây',
                        initialValue: _editTreeType,
                        onSaved: (val) => _editTreeType = val,
                      ),
                      _buildTextField(
                        label: 'Số lượng cây',
                        initialValue: _editTreeCount?.toString(),
                        keyboardType: TextInputType.number,
                        validator: (val) =>
                            int.tryParse(val!) == null ? 'Phải là số' : null,
                        onSaved: (val) => _editTreeCount = int.tryParse(val!),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _editSelectedArea,
                        items: _availableAreas
                            .map((area) => DropdownMenuItem(
                                  value: area,
                                  child: Text(area),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _editSelectedArea = val),
                        decoration: InputDecoration(
                          labelText: "Khu vực",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        validator: (val) => val == null ? 'Bắt buộc' : null,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _editStartDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
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
                            setState(() => _editStartDate = picked);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.green),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _editStartDate == null
                                  ? 'Chọn ngày bắt đầu'
                                  : 'Ngày bắt đầu: ${DateFormat('dd/MM/yyyy').format(_editStartDate!)}',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Hủy",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _updateProject(project.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Lưu",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteProject(String id) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                "Xác nhận xóa",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Bạn có chắc chắn muốn xóa dự án này?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text("Hủy"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteProject(id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text("Xóa"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Quản lý quy hoạch cây xanh",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green[800],
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProjectDialog,
        backgroundColor: Colors.green[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            )
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Chưa có dự án nào",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Nhấn nút + để thêm dự án mới",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchProjects,
                  color: Colors.green,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      final data =
                          project.data() as Map<String, dynamic>? ?? {};

                      // Xử lý ngày tháng an toàn
                      String startDate = 'Không rõ';
                      if (data['startDate'] != null) {
                        try {
                          // Thử parse theo ISO 8601
                          startDate = DateFormat('dd/MM/yyyy')
                              .format(DateTime.parse(data['startDate']));
                        } catch (e) {
                          // Nếu không được, thử parse theo các định dạng khác
                          try {
                            // Thử parse theo định dạng MM/dd/yyyy
                            List<String> dateParts =
                                data['startDate'].split('/');
                            if (dateParts.length == 3) {
                              DateTime parsedDate = DateTime(
                                  int.parse(dateParts[2]),
                                  int.parse(dateParts[0]),
                                  int.parse(dateParts[1]));
                              startDate =
                                  DateFormat('dd/MM/yyyy').format(parsedDate);
                            }
                          } catch (e) {
                            // Nếu vẫn lỗi, giữ nguyên giá trị mặc định
                            startDate = 'Không rõ';
                          }
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.nature,
                              color: Colors.green[800],
                              size: 30,
                            ),
                          ),
                          title: Text(
                            data['projectName'] ?? 'Chưa đặt tên',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    data['area_name'] ?? 'Không xác định',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    startDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey[600],
                            ),
                            onPressed: () => _showProjectDetails(project),
                          ),
                          onTap: () => _showProjectDetails(project),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
