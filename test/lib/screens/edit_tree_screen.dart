import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;

class EditTreeScreen extends StatefulWidget {
  final String treeId;
  final String userId;
  final String treeType;
  final String status;
  final String imageUrl;
  final Map<String, dynamic> location;
  final Map<String, dynamic> address;

  const EditTreeScreen({
    super.key,
    required this.treeId,
    required this.userId,
    required this.treeType,
    required this.status,
    required this.imageUrl,
    required this.location,
    required this.address,
  });

  @override
  State<EditTreeScreen> createState() => _EditTreeScreenState();
}

class _EditTreeScreenState extends State<EditTreeScreen> {
  late TextEditingController _treeTypeController;
  late TextEditingController _statusController;
  late TextEditingController _locationController;
  late TextEditingController _addressController;
  File? _newImageFile;
  bool isLoading = false;
  double? latitude;
  double? longitude;
  late osm.MapController mapController;
  AddressModel? _address;

  @override
  void initState() {
    super.initState();
    _treeTypeController = TextEditingController(text: widget.treeType);
    _statusController = TextEditingController(text: widget.status);
    _locationController = TextEditingController(
      text:
          "Vĩ độ: ${widget.location['lat']}, Kinh độ: ${widget.location['long']}",
    );
    _addressController = TextEditingController(
      text:
          "${widget.address['street']}, ${widget.address['district']}, ${widget.address['city']}, ${widget.address['country']}",
    );
    latitude = widget.location['lat'];
    longitude = widget.location['long'];
    mapController = osm.MapController(
      initMapWithUserPosition: const osm.UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _treeTypeController.dispose();
    _statusController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

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

        _address = AddressModel.fromLocation(place);

        if (_address!.district.isEmpty) {
          _address!.district =
              place.subAdministrativeArea ?? place.subLocality ?? "";
        }

        if (mounted) {
          setState(() {
            _locationController.text = "Vĩ độ: $latitude, Kinh độ: $longitude";
            _addressController.text =
                "${_address!.street}, ${_address!.district}, ${_address!.city}, ${_address!.country}";
          });
        }

        mapController.changeLocation(
          osm.GeoPoint(latitude: latitude!, longitude: longitude!),
        );
      } else {
        _showSnackBar("Không tìm thấy địa chỉ", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Lỗi khi lấy vị trí: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null && mounted) {
        setState(() {
          _newImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showSnackBar("Lỗi khi chọn ảnh: ${e.toString()}", Colors.red);
    }
  }

  Future<String?> _uploadImage() async {
    if (_newImageFile == null) return null;

    try {
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('tree_images/${widget.userId}/$fileName');

      UploadTask uploadTask = storageRef.putFile(_newImageFile!);
      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      _showSnackBar("Lỗi khi tải ảnh lên: ${e.toString()}", Colors.red);
      return null;
    }
  }

  Future<void> _updateTree() async {
    if (_treeTypeController.text.isEmpty ||
        latitude == null ||
        longitude == null) {
      _showSnackBar("Vui lòng nhập đầy đủ thông tin", Colors.orange);
      return;
    }

    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      String? uploadedImageUrl = await _uploadImage();
      String imageUrl = uploadedImageUrl ?? widget.imageUrl;

      if (uploadedImageUrl == null && _newImageFile != null) {
        _showSnackBar("Lỗi khi tải ảnh lên", Colors.red);
        return;
      }

      await FirebaseFirestore.instance
          .collection('trees')
          .doc(widget.treeId)
          .update({
        'treeType': _treeTypeController.text,
        'status': _statusController.text,
        'location': {'lat': latitude, 'long': longitude},
        'address': _address?.toJson(),
        'imageUrl': imageUrl,
        'timestamp': Timestamp.now(),
      });

      _showSnackBar("Cập nhật cây thành công!", Colors.green);
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar("Lỗi khi cập nhật cây: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa cây'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteTree,
          ),
        ],
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
              if (_newImageFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Image.file(
                    _newImageFile!,
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
                      onPressed: _updateTree,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                      ),
                      child: const Text('Lưu thay đổi'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTree() async {
    bool confirmDelete = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text('Bạn có chắc chắn muốn xóa cây này không?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmDelete) return;

    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('trees')
          .doc(widget.treeId)
          .delete();

      Reference photoRef = FirebaseStorage.instance.refFromURL(widget.imageUrl);
      await photoRef.delete();

      _showSnackBar("Xóa cây thành công!", Colors.green);
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar("Lỗi khi xóa cây: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
}

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
