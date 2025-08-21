import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_tree_screen.dart';
import 'add_tree_screen.dart';
import 'package:test/auth/auth.dart';
import 'map_view_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = "Loading...";
  int treeCount = 0;
  List<DocumentSnapshot> _trees = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _fetchTrees();
  }

  Future<void> _fetchUserInfo() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('auth')
          .doc(widget.userId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          username = userDoc['username'] ?? "Người dùng";
        });
      }
    } catch (e) {
      _showSnackBar(
          "Lỗi khi tải thông tin người dùng: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _fetchTrees() async {
    setState(() => isLoading = true);

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('trees')
          .where('userId', isEqualTo: widget.userId)
          .get();

      setState(() {
        _trees = querySnapshot.docs;
        treeCount = querySnapshot.size;
        isLoading = false;
      });
    } catch (e) {
      _showSnackBar("Lỗi khi tải danh sách cây: ${e.toString()}", Colors.red);
      setState(() => isLoading = false);
    }
  }

  void _navigateToEditScreen(DocumentSnapshot tree) async {
    bool? shouldRefresh = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTreeScreen(
          treeId: tree.id,
          userId: tree['userId'],
          treeType: tree['treeType'] ?? "Không xác định",
          location: tree['location'] ?? {"lat": 0.0, "long": 0.0},
          status: tree['status'] ?? "Không rõ",
          imageUrl: tree['imageUrl'] ?? "",
          address: tree['address'] ??
              {
                'street': 'Không có',
                'district': 'Không có',
                'city': 'Không có',
                'country': 'Không có',
              },
        ),
      ),
    );

    if (shouldRefresh == true) {
      _fetchTrees();
    }
  }

  void _navigateToAddTreeScreen() async {
    bool? shouldRefresh = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTreeScreen(userId: widget.userId),
      ),
    );

    if (shouldRefresh == true) {
      _fetchTrees();
    }
  }

  Future<void> _showLogoutDialog() async {
    bool confirmLogout = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận đăng xuất'),
            content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmLogout) {
      _logout();
    }
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AuthScreen()),
      );
    } catch (e) {
      _showSnackBar("Lỗi khi đăng xuất: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _navigateToMapView() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapViewScreen()),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Widget _buildSidebar() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(username, style: const TextStyle(fontSize: 18)),
            accountEmail: Text("Cây đã tải lên: $treeCount",
                style: const TextStyle(fontSize: 14, color: Colors.white70)),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 50, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Trang chủ"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.map, color: Colors.green),
            title: const Text("Bản đồ cây xanh"),
            onTap: () {
              Navigator.pop(context);
              _navigateToMapView();
            },
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text("Thêm cây mới"),
            onTap: () {
              Navigator.pop(context);
              _navigateToAddTreeScreen();
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Đăng xuất", style: TextStyle(color: Colors.red)),
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách cây'),
        backgroundColor: Colors.green,
      ),
      drawer: _buildSidebar(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trees.isEmpty
              ? const Center(
                  child: Text(
                    'Không có cây nào được thêm.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _trees.length,
                  itemBuilder: (context, index) {
                    var tree = _trees[index];

                    String treeType = tree['treeType'] ?? "Không xác định";
                    String status = tree['status'] ?? "Không rõ";
                    String imageUrl = tree['imageUrl'] ?? "";
                    Map<String, dynamic> location =
                        tree['location'] ?? {'lat': 0.0, 'long': 0.0};
                    Map<String, dynamic> address = tree['address'] ??
                        {
                          'street': 'Không có',
                          'district': 'Không có',
                          'city': 'Không có',
                          'country': 'Không có',
                        };

                    String fullAddress =
                        "${address['street']}, ${address['district']}, ${address['city']}, ${address['country']}";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      elevation: 4,
                      child: InkWell(
                        onTap: () => _navigateToEditScreen(tree),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error,
                                            stackTrace) =>
                                        const Icon(Icons.image_not_supported),
                                  ),
                                )
                              else
                                const Icon(Icons.image_not_supported, size: 80),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Loại cây: $treeType',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Địa chỉ: $fullAddress',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Trạng thái: $status',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Vị trí: ${location['lat']}, ${location['long']}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit, color: Colors.green),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddTreeScreen,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
