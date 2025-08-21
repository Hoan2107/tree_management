import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  late final WebViewController controller;
  bool _isLoading = true; // Biến để kiểm tra trạng thái tải dữ liệu

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            // Khi trang web tải xong, tải dữ liệu GeoJSON
            _loadGeoJSON();
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Tải file HTML ban đầu
    _loadHtmlFromAssets();
  }

  Future<void> _loadHtmlFromAssets() async {
    try {
      // Tải file HTML từ assets
      String htmlString = await rootBundle.loadString('assets/index.html');
      if (htmlString.isEmpty) {
        throw Exception('File index.html trống hoặc không tồn tại.');
      }
      await controller.loadHtmlString(htmlString);
    } catch (e) {
      print('❌ Lỗi tải HTML: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải HTML: $e')),
      );
    }
  }

  Future<void> _loadGeoJSON() async {
    try {
      // Tải file GeoJSON từ assets
      String geojsonString = await rootBundle.loadString('assets/test.geojson');
      if (geojsonString.isEmpty) {
        throw Exception('File geotest.geojson trống hoặc không tồn tại.');
      }
      // Chuyển dữ liệu GeoJSON vào WebView thông qua JavaScript
      await controller.runJavaScript('''
        window.receiveGeoJSON($geojsonString);
      ''');
    } catch (e) {
      print('❌ Lỗi tải GeoJSON: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải GeoJSON: $e')),
      );
    } finally {
      // Kết thúc quá trình tải
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Open Street Map',
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (_isLoading)
              const Center(
                child:
                    CircularProgressIndicator(), // Hiển thị loading indicator
              ),
          ],
        ),
      ),
    );
  }
}
