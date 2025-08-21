  import 'package:flutter/material.dart';
  import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
  import 'package:image_picker/image_picker.dart';
  import 'package:firebase_storage/firebase_storage.dart';
  import 'package:geolocator/geolocator.dart';
  import 'package:geocoding/geocoding.dart';
  import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
  import 'dart:io';

  // Model lưu thông tin địa chỉ
  class AddressModel {
    String name;
    String street;
    String city;
    String country;
    String district;

    AddressModel({
      this.name = "",
      this.street = "",
      this.district = "",
      this.city = "",
      this.country = "",
    });

    factory AddressModel.fromLocation(Placemark data) {
      return AddressModel(
        name: data.name ?? "",
        street: data.street ?? "",
        city: data.locality ?? data.administrativeArea ?? "",
        district: data.subLocality ?? data.subAdministrativeArea ?? "",
        country: data.country ?? "",
      );
    }

    Map<String, dynamic> toJson() => {
          'name': name,
          'street': street,
          'district': district,
          'city': city,
          'country': country,
        };
  }

  class AddTreeScreen extends StatefulWidget {
    final String userId;

    const AddTreeScreen({super.key, required this.userId});

    @override
    State<AddTreeScreen> createState() => _AddTreeScreenState();
  }

  class _AddTreeScreenState extends State<AddTreeScreen> {
    final TextEditingController _treeTypeController = TextEditingController();
    final TextEditingController _statusController = TextEditingController();
    final TextEditingController _locationController = TextEditingController();
    final TextEditingController _addressController = TextEditingController();

    File? _imageFile;
    bool isLoading = false;
    double? latitude;
    double? longitude;
    late osm.MapController mapController;
    AddressModel? _address;

    @override
    void initState() {
      super.initState();
      mapController = osm.MapController(
        initMapWithUserPosition: const osm.UserTrackingOption(
          enableTracking: true,
          unFollowUser: false,
        ),
      );
    }

    // Lấy vị trí GPS và địa chỉ chi tiết
    Future<void> _getCurrentLocation() async {
      setState(() => isLoading = true);

      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _showSnackBar("Vui lòng bật GPS để lấy vị trí", Colors.red);
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            _showSnackBar("Quyền truy cập vị trí bị từ chối", Colors.red);
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          _showSnackBar("Vị trí bị từ chối vĩnh viễn", Colors.red);
          return;
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        latitude = position.latitude;
        longitude = position.longitude;

        List<Placemark> placemarks =
            await placemarkFromCoordinates(latitude!, longitude!);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;

          // Lấy thông tin chi tiết từ Placemark
          _address = AddressModel.fromLocation(place);

          // Kiểm tra và điều chỉnh giá trị district nếu cần
          if (_address!.district.isEmpty) {
            _address!.district =
                place.subAdministrativeArea ?? place.subLocality ?? "";
          }

          // Cập nhật địa chỉ chi tiết
          setState(() {
            _locationController.text = "Vĩ độ: $latitude, Kinh độ: $longitude";
            _addressController.text =
                "${_address!.street}, ${_address!.district}, ${_address!.city}, ${_address!.country}";
          });

          // Cập nhật bản đồ
          mapController.changeLocation(
            osm.GeoPoint(latitude: latitude!, longitude: longitude!),
          );
        } else {
          _showSnackBar("Không tìm thấy địa chỉ", Colors.red);
        }
      } catch (e) {
        _showSnackBar("Lỗi khi lấy vị trí: ${e.toString()}", Colors.red);
      } finally {
        setState(() => isLoading = false);
      }
    }

    // Chọn hoặc chụp ảnh
    Future<void> _pickImage(ImageSource source) async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: source);

        if (pickedFile != null) {
          setState(() {
            _imageFile = File(pickedFile.path);
          });
        }
      } catch (e) {
        _showSnackBar("Lỗi khi chọn ảnh: ${e.toString()}", Colors.red);
      }
    }

    // Upload ảnh lên Firebase Storage
    Future<String?> _uploadImage() async {
      if (_imageFile == null) return null;

      try {
        String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('tree_images/${widget.userId}/$fileName');

        UploadTask uploadTask = storageRef.putFile(_imageFile!);
        TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        _showSnackBar("Lỗi khi tải ảnh lên: ${e.toString()}", Colors.red);
        return null;
      }
    }

    // Lưu dữ liệu cây vào Firestore
    Future<void> _addTree() async {
      if (_treeTypeController.text.isEmpty ||
          latitude == null ||
          longitude == null ||
          _imageFile == null) {
        _showSnackBar("Vui lòng nhập đầy đủ thông tin", Colors.orange);
        return;
      }

      setState(() => isLoading = true);

      try {
        String? uploadedImageUrl = await _uploadImage();

        if (uploadedImageUrl == null) {
          _showSnackBar("Lỗi khi tải ảnh lên", Colors.red);
          return;
        }

        await firestore.FirebaseFirestore.instance.collection('trees').add({
          'treeType': _treeTypeController.text,
          'status': _statusController.text,
          'location': {'lat': latitude, 'long': longitude},
          'address': _address?.toJson(),
          'imageUrl': uploadedImageUrl,
          'userId': widget.userId,
          'timestamp': firestore.Timestamp.now(),
        });

        _showSnackBar("Thêm cây thành công!", Colors.green);
        Navigator.pop(context, true);
      } catch (e) {
        _showSnackBar("Lỗi khi thêm cây: ${e.toString()}", Colors.red);
      } finally {
        setState(() => isLoading = false);
      }
    }

    // SnackBar thông báo
    void _showSnackBar(String message, Color color) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Thêm cây mới'),
          backgroundColor: Colors.green,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _treeTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Loại cây',
                    labelStyle: TextStyle(color: Colors.green),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                TextField(
                  controller: _statusController,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    labelStyle: TextStyle(color: Colors.green),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ',
                    labelStyle: TextStyle(color: Colors.green),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                  enabled: false,
                ),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Vị trí (Lat, Long)',
                    labelStyle: TextStyle(color: Colors.green),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 300,
                  child: osm.OSMFlutter(
                    controller: mapController,
                    osmOption: osm.OSMOption(
                      zoomOption: const osm.ZoomOption(
                        initZoom: 12,
                        minZoomLevel: 8,
                        maxZoomLevel: 19,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_imageFile != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Image.file(
                      _imageFile!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.camera),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Chụp ảnh'),
                    ),
                    ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Chọn ảnh'),
                    ),
                    ElevatedButton(
                      onPressed: _getCurrentLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Lấy vị trí'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _addTree,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                        ),
                        child: const Text('Thêm cây'),
                      ),
              ],
            ),
          ),
        ),
      );
    }
  }
