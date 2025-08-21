import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/animation.dart';
import 'package:test/screens/admin_screen.dart';
import 'package:test/screens/home_screen.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AuthModel? currentUser;

  Future<bool> login(String username, String password) async {
    CollectionReference authRef = FirebaseFirestore.instance.collection('auth');

    QuerySnapshot querySnapshot = await authRef
        .where('username', isEqualTo: username)
        .where('password', isEqualTo: password)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      currentUser = AuthModel.fromFirestore(querySnapshot.docs.first);
      return true;
    } else {
      currentUser = null;
      return false;
    }
  }

  Future<bool> register(String username, String password) async {
    CollectionReference authRef = FirebaseFirestore.instance.collection('auth');

    QuerySnapshot querySnapshot =
        await authRef.where('username', isEqualTo: username).get();

    if (querySnapshot.docs.isNotEmpty) {
      return false;
    }

    DocumentReference docRef = authRef.doc();

    AuthModel authModel = AuthModel(
      id: docRef.id,
      username: username,
      password: password,
      role: "USER",
      timestamp: Timestamp.now(),
    );
    await docRef.set(authModel.toJson());
    return true;
  }
}

class AuthModel {
  String id;
  String username;
  String password;
  String role;
  Timestamp timestamp;

  AuthModel({
    required this.id,
    required this.username,
    required this.password,
    this.role = "USER",
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "username": username,
      "password": password,
      "role": role,
      "timestamp": timestamp
    };
  }

  factory AuthModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AuthModel(
      id: doc.id,
      username: data['username'] ?? '',
      password: data['password'] ?? '',
      role: data['role'] ?? 'USER',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}

var userLogin = AuthModel(
    id: "",
    username: "",
    password: "",
    role: "USER",
    timestamp: Timestamp.now());

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  var isRegister = false;
  var isLoading = false;
  AuthModel authModel = AuthModel(
    id: "",
    username: "",
    password: "",
    role: "USER",
    timestamp: Timestamp.now(),
  );

  String confirmPassword = "";
  String? errorPassword;
  String? errorConfirmPassword;
  String? errorUserName;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void validateForm(BuildContext context) {
    bool isValidated = true;
    setState(() {
      errorUserName = null;
      errorPassword = null;
      errorConfirmPassword = null;
    });

    if (authModel.username.isEmpty) {
      isValidated = false;
      setState(() {
        errorUserName = "Tên người dùng không được để trống";
      });
    }
    if (authModel.password.isEmpty) {
      isValidated = false;
      setState(() {
        errorPassword = "Mật khẩu không được để trống";
      });
    }
    if (isRegister) {
      if (confirmPassword.isEmpty) {
        isValidated = false;
        setState(() {
          errorConfirmPassword = "Vui lòng nhập lại mật khẩu";
        });
      } else if (authModel.password != confirmPassword) {
        isValidated = false;
        setState(() {
          errorConfirmPassword = "Mật khẩu nhập lại không khớp";
        });
      }
    }

    if (isValidated) {
      loading(true);
      if (isRegister) {
        AuthService()
            .register(authModel.username, authModel.password)
            .then((success) {
          if (success) {
            loginUser(context);
          } else {
            loading(false);
            setState(() {
              errorUserName = "Tài khoản đã tồn tại";
            });
          }
        });
      } else {
        loginUser(context);
      }
    }
  }

  Future<void> loginUser(BuildContext context) async {
    bool success =
        await AuthService().login(authModel.username, authModel.password);
    if (success) {
      AuthModel loggedInUser = AuthService().currentUser!;
      userLogin = loggedInUser;

      if (loggedInUser.role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userId: loggedInUser.id),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tên người dùng hoặc mật khẩu không chính xác.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      loading(false);
    }
  }

  void loading(bool value) {
    setState(() {
      isLoading = value;
    });
  }

  void _toggleAuthMode() {
    setState(() {
      isRegister = !isRegister;
      _controller.reset();
      _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/login.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Container(
                  color: Colors.white,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isRegister ? 'Tạo tài khoản' : 'Chào mừng trở lại',
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    isRegister 
                                      ? 'Điền thông tin để tạo tài khoản mới'
                                      : 'Đăng nhập để tiếp tục',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 40),
                          _buildAuthForm(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4361EE)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthForm(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: "Tên người dùng",
                labelStyle: GoogleFonts.poppins(
                  color: Colors.grey[600],
                ),
                prefixIcon: Icon(Icons.person_outline, color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Color(0xFF4361EE), width: 2),
                ),
                errorText: errorUserName,
                errorStyle: GoogleFonts.poppins(),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              ),
              style: GoogleFonts.poppins(),
              onChanged: (value) {
                authModel.username = value;
              },
            ),
            SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: "Mật khẩu",
                labelStyle: GoogleFonts.poppins(
                  color: Colors.grey[600],
                ),
                prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Color(0xFF4361EE), width: 2),
                ),
                errorText: errorPassword,
                errorStyle: GoogleFonts.poppins(),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              ),
              obscureText: obscurePassword,
              style: GoogleFonts.poppins(),
              onChanged: (value) {
                authModel.password = value;
              },
            ),
            if (isRegister) ...[
              SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: "Xác nhận mật khẩu",
                  labelStyle: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFF4361EE), width: 2),
                  ),
                  errorText: errorConfirmPassword,
                  errorStyle: GoogleFonts.poppins(),
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                ),
                obscureText: obscureConfirmPassword,
                style: GoogleFonts.poppins(),
                onChanged: (value) {
                  confirmPassword = value;
                },
              ),
            ],
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => validateForm(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4361EE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                  shadowColor: Color(0xFF4361EE).withOpacity(0.3),
                ),
                child: Text(
                  isRegister ? "ĐĂNG KÝ" : "ĐĂNG NHẬP",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: _toggleAuthMode,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(
                        text: isRegister 
                          ? 'Đã có tài khoản? '
                          : 'Chưa có tài khoản? ',
                      ),
                      TextSpan(
                        text: isRegister ? 'Đăng nhập' : 'Đăng ký ngay',
                        style: GoogleFonts.poppins(
                          color: Color(0xFF4361EE),
                          fontWeight: FontWeight.w600,
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