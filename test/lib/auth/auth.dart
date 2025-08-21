import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      return false; // Tài khoản đã tồn tại
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
    return true; // Đăng ký thành công
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

class _AuthScreenState extends State<AuthScreen> {
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
        const SnackBar(
          content: Text('Tên người dùng hoặc mật khẩu không chính xác.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _renderContent(context),
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _renderContent(BuildContext context) {
    return Column(
      children: [
        Expanded(child: Image.asset('assets/login.png', fit: BoxFit.cover)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "Tên người dùng",
                    labelText: "Tên người dùng",
                    errorText: errorUserName,
                  ),
                  onChanged: (value) {
                    authModel.username = value;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    hintText: "Mật khẩu",
                    labelText: "Mật khẩu",
                    errorText: errorPassword,
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: obscurePassword,
                  onChanged: (value) {
                    authModel.password = value;
                  },
                ),
                if (isRegister) ...[
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Nhập lại mật khẩu",
                      labelText: "Xác nhận mật khẩu",
                      errorText: errorConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: obscureConfirmPassword,
                    onChanged: (value) {
                      confirmPassword = value;
                    },
                  ),
                ],
                const SizedBox(height: 50),
                ElevatedButton(
                  onPressed: () => validateForm(context),
                  child: Text(isRegister ? "Đăng kí" : "Đăng nhập"),
                ),
                TextButton(
                  onPressed: () => setState(() => isRegister = !isRegister),
                  child: Text(isRegister ? "Đăng nhập" : "Đăng kí"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
