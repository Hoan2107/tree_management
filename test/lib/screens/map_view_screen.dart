import 'dart:io';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class MapViewScreen extends StatefulWidget {
  final bool interactive;

  const MapViewScreen({
    super.key,
    this.interactive = true,
  });

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  late final bool interactive = widget.interactive;

  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  bool _isLoading = true;

  String? _geoJsonString;
  List<Map<String, dynamic>> _csvData = [];

  InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllowFullscreen: true,
    javaScriptEnabled: true,
  );

  @override
  void initState() {
    super.initState();
    _loadGeoJSON();

    if (kIsWeb) {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        'map-frame',
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = 'assets/index.html'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';

          iframe.onLoad.listen((event) {
            if (_geoJsonString != null) {
              iframe.contentWindow?.postMessage(
                _geoJsonString!,
                '*',
              );
            }
          });

          return iframe;
        },
      );
    }
  }

  Future<void> _loadGeoJSON() async {
    try {
      _geoJsonString = await rootBundle.loadString('assets/test.geojson');
      if (_geoJsonString == null || _geoJsonString!.isEmpty) {
        throw Exception('GeoJSON file is empty or missing.');
      }
    } catch (e) {
      print('❌ Error loading GeoJSON: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading GeoJSON: $e')),
        );
      }
    }
  }

  Future<void> _importCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        _csvData = fields
            .sublist(1)
            .map((row) {
              try {
                return {
                  "name": row[0].toString().trim(),
                  "lat": double.tryParse(row[1].toString()) ?? 0.0,
                  "lng": double.tryParse(row[2].toString()) ?? 0.0,
                  "street": row.length > 3 ? row[3].toString().trim() : "",
                };
              } catch (e) {
                return null;
              }
            })
            .where((item) => item != null)
            .cast<Map<String, dynamic>>()
            .toList();

        _sendCSVDataToMap();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã nhập ${_csvData.length} điểm từ CSV')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi nhập CSV: $e')),
        );
      }
    }
  }

  void _sendCSVDataToMap() {
    if (_csvData.isEmpty || webViewController == null) return;

    final csvJson = json.encode(_csvData);
    webViewController?.evaluateJavascript(source: '''
      if (typeof window.receiveCSVData === 'function') {
        window.receiveCSVData($csvJson);
      } else {
        console.warn("receiveCSVData function not defined.");
      }
    ''');
  }

  void _injectGeoJSON() {
    if (_geoJsonString == null || webViewController == null) return;

    webViewController?.evaluateJavascript(source: '''
      if (typeof window.receiveGeoJSON === 'function') {
        window.receiveGeoJSON(${_geoJsonString!});
      } else {
        console.warn("receiveGeoJSON function not defined.");
      }
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ'),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _importCSV,
              tooltip: 'Nhập file CSV',
            ),
        ],
      ),
      body: SafeArea(
        child: kIsWeb
            ? const HtmlElementView(viewType: 'map-frame')
            : Stack(
                children: [
                  InAppWebView(
                    key: webViewKey,
                    initialData: InAppWebViewInitialData(data: _mapHtml),
                    initialSettings: settings,
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                    },
                    onLoadStop: (controller, url) async {
                      _injectGeoJSON();
                      setState(() {
                        _isLoading = false;
                      });
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      if (kDebugMode) {
                        print(consoleMessage);
                      }
                    },
                  ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
      ),
    );
  }

  final String _mapHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bản đồ Quản lý Cây xanh</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet/dist/leaflet.css" />
  <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster/dist/MarkerCluster.css" />
  <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster/dist/MarkerCluster.Default.css" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" />
  <script src="https://unpkg.com/leaflet/dist/leaflet.js"></script>
  <script src="https://unpkg.com/leaflet.markercluster/dist/leaflet.markercluster.js"></script>
  <script src="https://unpkg.com/@turf/turf@6/turf.min.js"></script>
  <style>
    html, body, #map { margin:0; padding:0; height:100%; width:100%; }
    #controls {
      position:absolute; z-index:1000; background:#fff; border-radius:8px; padding:10px; 
      box-shadow: 0 2px 10px rgba(0,0,0,0.2); top:10px; right:10px; width: 250px;
    }
    .control-group { margin-bottom:8px; }
    .control-group h3 { margin: 5px 0; font-size: 14px; color: #2c3e50; }
    button { 
      margin:2px 0; padding:6px 10px; border:none; border-radius:4px; cursor:pointer; 
      background: #ecf0f1; width: 100%; text-align: left;
    }
    button:hover { background: #bdc3c7; }
    button.active { background:#27ae60; color:#fff; }
    button i { margin-right: 8px; width: 16px; text-align: center; }
    .area-info {
      position:absolute; z-index:1000; background:#fff; border-radius:8px; padding:10px; 
      font-size:13px; bottom:10px; left:10px; max-width:250px; box-shadow: 0 2px 10px rgba(0,0,0,0.2);
    }
    .tree-icon, .admin-tree-icon {
      background-size:cover; width:24px; height:24px;
    }
    .leaflet-marker-icon {
      pointer-events: auto !important;
    }
    .tree-popup img {
      max-width: 100%;
      margin-top: 8px;
      border-radius: 4px;
    }
    .popup-actions {
      margin-top: 10px;
      display: flex;
      gap: 5px;
    }
    .popup-actions button {
      padding: 4px 8px;
      font-size: 12px;
      width: auto;
    }
    .edit-form {
      margin-top: 10px;
    }
    .edit-form label {
      display: block;
      margin-top: 5px;
      font-weight: bold;
      font-size: 12px;
    }
    .edit-form input, .edit-form select, .edit-form textarea {
      width: 100%;
      padding: 5px;
      margin-top: 3px;
      box-sizing: border-box;
      border: 1px solid #ddd;
      border-radius: 3px;
    }
    .form-buttons {
      margin-top: 10px;
      display: flex;
      gap: 5px;
    }
    .area-marker {
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: bold;
    }
    .legend {
      padding: 6px 8px;
      background: white;
      background: rgba(255,255,255,0.9);
      box-shadow: 0 0 15px rgba(0,0,0,0.2);
      border-radius: 5px;
      line-height: 18px;
      color: #555;
      font-size: 12px;
    }
    .legend i {
      width: 18px;
      height: 18px;
      float: left;
      margin-right: 8px;
      opacity: 0.7;
      border-radius: 50%;
    }
    .marker-cluster {
      background-clip: padding-box;
      border-radius: 20px;
    }
    .marker-cluster div {
      width: 30px;
      height: 30px;
      margin-left: 5px;
      margin-top: 5px;
      text-align: center;
      border-radius: 15px;
      font: 12px "Helvetica Neue", Arial, Helvetica, sans-serif;
      font-weight: bold;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .marker-cluster span {
      line-height: 30px;
    }
    .stats-panel {
      background: rgba(255,255,255,0.9);
      padding: 10px;
      border-radius: 8px;
      margin-top: 10px;
    }
    .stats-item {
      margin: 5px 0;
      font-size: 12px;
    }
    .stats-value {
      font-weight: bold;
      color: #27ae60;
    }
    .filter-group {
      margin-top: 10px;
    }
    .filter-group select {
      width: 100%;
      padding: 5px;
      border: 1px solid #ddd;
      border-radius: 3px;
      margin-top: 3px;
    }
    .tree-healthy { color: #27ae60; }
    .tree-sick { color: #f39c12; }
    .tree-dead { color: #e74c3c; }
  </style>
</head>
<body>
  <div id="map"></div>
  <div id="controls">
    <div class="control-group">
      <h3>Bản đồ nền</h3>
      <button id="toggleOSM"><i class="fas fa-map"></i> Bản đồ OSM</button>
      <button id="toggleSatellite"><i class="fas fa-satellite"></i> Ảnh vệ tinh</button>
    </div>
    <div class="control-group">
      <h3>Hiển thị</h3>
      <button id="toggleGeoJSON"><i class="fas fa-layer-group"></i> Khu vực</button>
      <button id="showAllTrees"><i class="fas fa-tree"></i> Hiển thị tất cả cây</button>
    </div>
    <div class="control-group filter-group">
      <h3>Lọc cây</h3>
      <select id="filterTreeType">
        <option value="">Tất cả loại cây</option>
      </select>
      <select id="filterTreeStatus">
        <option value="">Tất cả tình trạng</option>
        <option value="healthy">Khỏe mạnh</option>
        <option value="sick">Bị bệnh</option>
        <option value="dead">Đã chết</option>
      </select>
    </div>
    <div class="stats-panel">
      <h3>Thống kê</h3>
      <div class="stats-item">Tổng số cây: <span id="totalTreesCount" class="stats-value">0</span></div>
      <div class="stats-item">Cây khỏe mạnh: <span id="healthyTreesCount" class="stats-value tree-healthy">0</span></div>
      <div class="stats-item">Cây bị bệnh: <span id="sickTreesCount" class="stats-value tree-sick">0</span></div>
      <div class="stats-item">Cây đã chết: <span id="deadTreesCount" class="stats-value tree-dead">0</span></div>
      <div class="stats-item">Khu vực: <span id="areasCount" class="stats-value">0</span></div>
    </div>
  </div>

  <div id="legend" class="legend">
    <h4>Mật độ cây</h4>
    <div><i style="background:#ff0000"></i>0-20 cây</div>
    <div><i style="background:#a1dab4"></i>20-50 cây</div>
    <div><i style="background:#41b6c4"></i>50-100 cây</div>
    <div><i style="background:#2c7fb8"></i>100-200 cây</div>
    <div><i style="background:#253494"></i>Trên 200 cây</div>
  </div>

  <div id="areaInfo" class="area-info">
    <h3 id="areaName"></h3>
    <p>Diện tích: <span id="areaSize">0</span> km²</p>
    <p>Tổng số cây: <span id="totalTrees">0</span></p>
    <p>Cây người dùng: <span id="treesCount">0</span></p>
    <p>Cây quản lý: <span id="adminTreesCount">0</span></p>
    <div class="popup-actions">
      <button onclick="document.getElementById('areaInfo').style.display='none'"><i class="fas fa-times"></i> Đóng</button>
      <button id="zoomToArea"><i class="fas fa-search"></i> Phóng to</button>
    </div>
  </div>

  <script type="module">
    import { initializeApp } from 'https://www.gstatic.com/firebasejs/9.6.0/firebase-app.js';
    import { getFirestore, collection, getDocs, doc, deleteDoc, updateDoc, getDoc } from 'https://www.gstatic.com/firebasejs/9.6.0/firebase-firestore.js';

    const firebaseApp = initializeApp({
      apiKey: "AIzaSyAQO2BmNaZcast3fRMTUUo7FzvuupdTE0w",
      authDomain: "compact-mystery-420806.firebaseapp.com",
      projectId: "compact-mystery-420806",
      storageBucket: "compact-mystery-420806.appspot.com",
      messagingSenderId: "1072971256470",
      appId: "1:1072971256470:web:1fd0e2d50054f48a9328b7",
      measurementId: "G-5MDD2BR4PL"
    });

    const db = getFirestore(firebaseApp);
    const treesRef = collection(db, 'trees');
    const adminTreeRef = collection(db, 'admin_tree');

    const map = L.map('map').setView([21.0763, 105.7796], 12);
    const osm = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
    const satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}');

    let geojsonLayer, selectedAreaLayer, allTrees = [], 
        areaMarkersGroup = L.layerGroup().addTo(map),
        treeClusters = {},
        areaColors = {},
        currentZoom = map.getZoom(),
        ZOOM_THRESHOLD = 14,
        individualMarkersGroup = L.layerGroup(),
        areaClusterGroup = L.layerGroup(),
        currentArea = null,
        treeTypes = new Set(),
        treeMarkers = L.layerGroup().addTo(map);

    const COMMON_TREE_TYPES = [
      "Bàng", "Phượng vĩ", "Xà cừ", "Sấu", "Bằng lăng", 
      "Lộc vừng", "Sưa", "Lim", "Sồi", "Thông", 
      "Bạch đàn", "Keo", "Muồng", "Hoàng lan", "Sao đen"
    ];

    // Icon cho các loại cây
    const treeIcon = L.icon({
      iconUrl: 'https://png.pngtree.com/png-vector/20220910/ourmid/pngtree-one-fresh-cartoon-green-leaf-png-image_6157397.png',
      iconSize: [30, 30]
    });

    const adminIcon = L.icon({
      iconUrl: 'https://png.pngtree.com/png-vector/20220910/ourmid/pngtree-one-fresh-cartoon-green-leaf-png-image_6157397.png',
      iconSize: [30, 30]
    });

    const legend = L.control({position: 'bottomright'});
    legend.onAdd = function(map) {
      const div = L.DomUtil.get('legend');
      return div;
    };
    legend.addTo(map);

    function getColorByTreeCount(count) {
      count = count || 0;
      return count > 200 ? '#253494' :
             count > 100 ? '#2c7fb8' :
             count > 50  ? '#41b6c4' :
             count > 20  ? '#a1dab4' :
                           '#ff0000';
    }

    function updateStats() {
      const totalTrees = allTrees.length;
      const healthyTrees = allTrees.filter(t => t.data.status === 'healthy').length;
      const sickTrees = allTrees.filter(t => t.data.status === 'sick').length;
      const deadTrees = allTrees.filter(t => t.data.status === 'dead').length;
      const areasCount = geojsonLayer ? Object.keys(treeClusters).length : 0;

      document.getElementById('totalTreesCount').textContent = totalTrees;
      document.getElementById('healthyTreesCount').textContent = healthyTrees;
      document.getElementById('sickTreesCount').textContent = sickTrees;
      document.getElementById('deadTreesCount').textContent = deadTrees;
      document.getElementById('areasCount').textContent = areasCount;
    }

    function updateZoomView() {
      if (currentZoom < ZOOM_THRESHOLD) {
        if (map.hasLayer(individualMarkersGroup)) {
          map.removeLayer(individualMarkersGroup);
        }
        
        Object.values(treeClusters).forEach(cluster => {
          if (map.hasLayer(cluster)) {
            map.removeLayer(cluster);
          }
        });
        
        if (!map.hasLayer(areaClusterGroup)) {
          map.addLayer(areaClusterGroup);
        }
      } else {
        if (map.hasLayer(areaClusterGroup)) {
          map.removeLayer(areaClusterGroup);
        }
        
        if (currentArea) {
          const areaCluster = treeClusters[currentArea.properties.name];
          if (areaCluster && !map.hasLayer(areaCluster)) {
            map.addLayer(areaCluster);
          }
        } else {
          Object.entries(treeClusters).forEach(([areaName, cluster]) => {
            if (!map.hasLayer(cluster)) {
              map.addLayer(cluster);
            }
          });
        }
      }
    }

    function createActionButtons(docId, collectionName, marker, data) {
      const actionsDiv = document.createElement('div');
      actionsDiv.className = 'popup-actions';
      
      const deleteBtn = document.createElement('button');
      deleteBtn.innerHTML = '<i class="fas fa-trash"></i> Xóa';
      deleteBtn.style.backgroundColor = '#e74c3c';
      deleteBtn.style.color = 'white';
      deleteBtn.onclick = async (e) => {
        e.stopPropagation();
        if (confirm('Bạn có chắc chắn muốn xóa cây này?')) {
          try {
            if (collectionName === 'admin_tree') {
              const docRef = doc(db, collectionName, docId);
              const docSnap = await getDoc(docRef);
              const currentData = docSnap.data();
              const trees = currentData.trees;
              
              const treeIndex = trees.findIndex(t => 
                t.lat === data.lat && 
                t.lng === data.lng &&
                t.treeType === data.treeType
              );
              
              if (treeIndex !== -1) {
                trees.splice(treeIndex, 1);
                await updateDoc(docRef, { trees: trees });
                marker.remove();
                alert('Đã xóa cây thành công');
                loadTrees();
              } else {
                alert('Không tìm thấy cây cần xóa');
              }
            } else {
              await deleteDoc(doc(db, collectionName, docId));
              marker.remove();
              alert('Đã xóa cây thành công');
              loadTrees();
            }
          } catch (error) {
            alert('Lỗi khi xóa cây: ' + error.message);
          }
        }
      };
      
      const editBtn = document.createElement('button');
      editBtn.innerHTML = '<i class="fas fa-edit"></i> Sửa';
      editBtn.style.backgroundColor = '#3498db';
      editBtn.style.color = 'white';
      editBtn.onclick = (e) => {
        e.stopPropagation();
        showEditForm(docId, collectionName, marker, data);
      };
      
      actionsDiv.appendChild(editBtn);
      actionsDiv.appendChild(deleteBtn);
      return actionsDiv;
    }

    function showEditForm(docId, collectionName, marker, data) {
      const popupContent = document.createElement('div');
      popupContent.className = 'tree-popup';
      
      const form = document.createElement('div');
      form.className = 'edit-form';
      
      if (collectionName === 'trees') {
        form.innerHTML = '<h3>Sửa thông tin cây</h3>' +
          '<label>Tình trạng:</label>' +
          '<select id="editStatus">' +
            '<option value="healthy"' + (data.status === 'healthy' ? ' selected' : '') + '>Khỏe mạnh</option>' +
            '<option value="sick"' + (data.status === 'sick' ? ' selected' : '') + '>Bị bệnh</option>' +
            '<option value="dead"' + (data.status === 'dead' ? ' selected' : '') + '>Đã chết</option>' +
          '</select>' +
          '<label>Đường:</label>' +
          '<input type="text" id="editStreet" value="' + (data.street || '') + '">' +
          '<label>Quận:</label>' +
          '<input type="text" id="editDistrict" value="' + (data.address?.district || '') + '">' +
          '<label>Thành phố:</label>' +
          '<input type="text" id="editCity" value="' + (data.address?.city || '') + '">' +
          '<label>Ghi chú:</label>' +
          '<textarea id="editNotes">' + (data.notes || '') + '</textarea>';
      } else {
        form.innerHTML = '<h3>Sửa thông tin cây quản lý</h3>' +
          '<label>Tên:</label>' +
          '<input type="text" id="editName" value="' + (data.name || '') + '">' +
          '<label>Đường:</label>' +
          '<input type="text" id="editStreet" value="' + (data.street || '') + '">' +
          '<label>Vĩ độ:</label>' +
          '<input type="number" id="editLat" step="0.000001" value="' + (data.lat || '') + '">' +
          '<label>Kinh độ:</label>' +
          '<input type="number" id="editLng" step="0.000001" value="' + (data.lng || '') + '">' +
          '<label>Loại cây:</label>' +
          '<select id="editTreeType">' +
            COMMON_TREE_TYPES.map(type => 
            '"<option value=\\"" + type + "\\" " + (data.treeType === type ? "selected" : "") + ">" + type + "</option>"'
            ).join('') +
            '<option value="other"' + (!COMMON_TREE_TYPES.includes(data.treeType) ? ' selected' : '') + '>Khác</option>' +
          '</select>' +
          '<div id="otherTreeTypeContainer" style="' + (!COMMON_TREE_TYPES.includes(data.treeType) ? '' : 'display:none;') + 'margin-top:5px;">' +
            '<label>Nhập loại cây khác:</label>' +
            '<input type="text" id="editOtherTreeType" value="' + (!COMMON_TREE_TYPES.includes(data.treeType) ? (data.treeType || '') : '') + '">' +
          '</div>' +
          '<label>Ngày trồng:</label>' +
          '<input type="date" id="editPlantingDate" value="' + (data.plantingDate || '') + '">' +
          '<label>Tình trạng:</label>' +
          '<select id="editStatus">' +
            '<option value="healthy"' + (data.status === 'healthy' ? ' selected' : '') + '>Khỏe mạnh</option>' +
            '<option value="sick"' + (data.status === 'sick' ? ' selected' : '') + '>Bị bệnh</option>' +
            '<option value="dead"' + (data.status === 'dead' ? ' selected' : '') + '>Đã chết</option>' +
          '</select>';
      }
      
      if (collectionName === 'admin_tree') {
        const treeTypeSelect = form.querySelector('#editTreeType');
        treeTypeSelect.addEventListener('change', function() {
          const otherContainer = form.querySelector('#otherTreeTypeContainer');
          if (this.value === 'other') {
            otherContainer.style.display = 'block';
          } else {
            otherContainer.style.display = 'none';
          }
        });
      }
      
      const buttonsDiv = document.createElement('div');
      buttonsDiv.className = 'form-buttons';
      
      const saveBtn = document.createElement('button');
      saveBtn.innerHTML = '<i class="fas fa-save"></i> Lưu';
      saveBtn.style.backgroundColor = '#2ecc71';
      saveBtn.style.color = 'white';
      saveBtn.onclick = async () => {
        try {
          if (collectionName === 'trees') {
            await updateUserTree(docId, marker);
          } else {
            await updateAdminTree(docId, marker, data);
          }
          marker.closePopup();
          loadTrees();
        } catch (error) {
          alert('Lỗi khi cập nhật cây: ' + error.message);
        }
      };
      
      const cancelBtn = document.createElement('button');
      cancelBtn.innerHTML = '<i class="fas fa-times"></i> Hủy';
      cancelBtn.style.backgroundColor = '#95a5a6';
      cancelBtn.style.color = 'white';
      cancelBtn.onclick = () => marker.closePopup();
      
      buttonsDiv.appendChild(saveBtn);
      buttonsDiv.appendChild(cancelBtn);
      
      popupContent.appendChild(form);
      popupContent.appendChild(buttonsDiv);
      
      marker.setPopupContent(popupContent);
      marker.openPopup();
    }

    async function updateUserTree(docId, marker) {
      const updatedData = {
        status: document.getElementById('editStatus').value,
        street: document.getElementById('editStreet').value,
        address: {
          district: document.getElementById('editDistrict').value,
          city: document.getElementById('editCity').value
        },
        notes: document.getElementById('editNotes').value
      };
      
      await updateDoc(doc(db, 'trees', docId), updatedData);
      alert('Đã cập nhật thông tin cây thành công');
      
      const actions = createActionButtons(docId, 'trees', marker, updatedData);
      const popupContent = createUserTreePopup(docId, updatedData);
      popupContent.appendChild(actions);
      marker.setPopupContent(popupContent);
    }

    async function updateAdminTree(docId, marker, originalData) {
      let treeType = document.getElementById('editTreeType').value;
      if (treeType === 'other') {
        treeType = document.getElementById('editOtherTreeType').value;
      }
      
      const updatedTree = {
        name: document.getElementById('editName').value,
        street: document.getElementById('editStreet').value,
        lat: parseFloat(document.getElementById('editLat').value),
        lng: parseFloat(document.getElementById('editLng').value),
        treeType: treeType,
        plantingDate: document.getElementById('editPlantingDate').value,
        status: document.getElementById('editStatus').value
      };
      
      const docRef = doc(db, 'admin_tree', docId);
      const docSnap = await getDoc(docRef);
      const currentData = docSnap.data();
      const trees = currentData.trees;
      
      const treeIndex = trees.findIndex(t => 
        t.lat === originalData.lat && 
        t.lng === originalData.lng &&
        t.treeType === originalData.treeType
      );
      
      if (treeIndex !== -1) {
        trees[treeIndex] = updatedTree;
        await updateDoc(docRef, { trees: trees });
        alert('Đã cập nhật cây quản lý thành công');
        
        if (marker.getLatLng().lat !== updatedTree.lat || marker.getLatLng().lng !== updatedTree.lng) {
          marker.setLatLng([updatedTree.lat, updatedTree.lng]);
        }
        
        const actions = createActionButtons(docId, 'admin_tree', marker, updatedTree);
        const popupContent = createAdminTreePopup(docId, updatedTree);
        popupContent.appendChild(actions);
        marker.setPopupContent(popupContent);
      } else {
        alert('Không tìm thấy cây cần cập nhật');
      }
    }

    function createUserTreePopup(docId, data) {
      const status = data.status || 'Không rõ';
      const street = data.street || '';
      const district = data.address?.district || '';
      const city = data.address?.city || '';
      const timestamp = data.timestamp ? new Date(data.timestamp.seconds * 1000).toLocaleDateString() : 'Không rõ';
      const image = data.imageUrl ? '<img src="' + data.imageUrl + '" class="tree-popup-img">' : '';
      
      const popupContent = document.createElement('div');
      popupContent.className = 'tree-popup';
      popupContent.innerHTML = '<p><strong>Tình trạng:</strong> ' + status + '</p>' +
             '<p><strong>Địa chỉ:</strong> ' + street + ', ' + district + ', ' + city + '</p>' +
             '<p><strong>Ngày trồng:</strong> ' + timestamp + '</p>' +
             '<p><strong>Ghi chú:</strong> ' + (data.notes || '') + '</p>' +
             image;
      
      return popupContent;
    }

    function createAdminTreePopup(docId, data) {
      const street = data.street || 'Không rõ';
      const lat = data.lat ? data.lat.toFixed(6) : '?';
      const lng = data.lng ? data.lng.toFixed(6) : '?';
      const treeType = data.treeType || 'Không rõ';
      const plantingDate = data.plantingDate || 'Không rõ';
      const name = data.name || 'Không rõ';
      const status = data.status || 'Không rõ';
      
      const popupContent = document.createElement('div');
      popupContent.className = 'tree-popup';
      popupContent.innerHTML = '<p><strong>Tên:</strong> ' + name + '</p>' +
         '<p><strong>Đường:</strong> ' + street + '</p>' +
         '<p><strong>Tọa độ:</strong> ' + lat + ', ' + lng + '</p>' +
         '<p><strong>Loại cây:</strong> ' + treeType + '</p>' +
         '<p><strong>Ngày trồng:</strong> ' + plantingDate + '</p>' +
         '<p><strong>Tình trạng:</strong> ' + status + '</p>';
      
      return popupContent;
    }

    function isInPolygon(lat, lng, poly) {
      return turf.booleanPointInPolygon(turf.point([lng, lat]), poly);
    }

    function showAreaInfo(f) {
      currentArea = f;
      const poly = turf.multiPolygon(f.geometry.coordinates);
      const areaName = f.properties.name;
      
      const inArea = allTrees.filter(t => isInPolygon(t.lat, t.lng, poly));
      const userCount = inArea.filter(t => t.source === 'trees').length;
      const adminCount = inArea.filter(t => t.source === 'admin_tree').length;

      document.getElementById('areaName').textContent = areaName;
      document.getElementById('areaSize').textContent = f.properties.area_km2.toFixed(2);
      document.getElementById('totalTrees').textContent = inArea.length;
      document.getElementById('treesCount').textContent = userCount;
      document.getElementById('adminTreesCount').textContent = adminCount;
      document.getElementById('areaInfo').style.display = 'block';

      if (selectedAreaLayer) map.removeLayer(selectedAreaLayer);
      selectedAreaLayer = L.geoJSON(f, { 
        style: { 
          color: '#27ae60', 
          weight: 3, 
          fillOpacity: 0.3 
        } 
      }).addTo(map);
      
      const areaCluster = treeClusters[areaName];
      if (areaCluster) {
        Object.entries(treeClusters).forEach(([name, cluster]) => {
          if (name !== areaName && map.hasLayer(cluster)) {
            map.removeLayer(cluster);
          }
        });
        
        if (!map.hasLayer(areaCluster)) {
          map.addLayer(areaCluster);
        }
        
        map.fitBounds(selectedAreaLayer.getBounds());
      }
      
      document.getElementById('zoomToArea').onclick = () => {
        map.fitBounds(selectedAreaLayer.getBounds());
      };
    }

    async function loadTrees() {
      allTrees = [];
      treeTypes.clear();
      areaMarkersGroup.clearLayers();
      areaClusterGroup.clearLayers();
      individualMarkersGroup.clearLayers();
      treeClusters = {};
      areaColors = {};
      currentArea = null;
      
      const [tSnap, aSnap] = await Promise.all([getDocs(treesRef), getDocs(adminTreeRef)]);
      const areaCounts = {};

      tSnap.forEach(doc => {
        const data = doc.data();
        if (data.location?.lat && data.location?.long) {
          const marker = L.marker([data.location.lat, data.location.long], { 
            icon: treeIcon,
            docId: doc.id,
            collection: 'trees'
          });
          
          const popupContent = createUserTreePopup(doc.id, data);
          const actions = createActionButtons(doc.id, 'trees', marker, data);
          popupContent.appendChild(actions);
          marker.bindPopup(popupContent);
          
          allTrees.push({ 
            lat: data.location.lat, 
            lng: data.location.long, 
            source: 'trees',
            data: data,
            marker: marker
          });
          
          if (data.treeType) {
            treeTypes.add(data.treeType);
          }
        }
      });

      aSnap.forEach(doc => {
        const data = doc.data();
        if (data.trees) {
          data.trees.forEach((tree, index) => {
            if (tree.lat && tree.lng) {
              const marker = L.marker([tree.lat, tree.lng], { 
                icon: adminIcon,
                docId: doc.id,
                collection: 'admin_tree'
              });
              
              const popupContent = createAdminTreePopup(doc.id, tree);
              const actions = createActionButtons(doc.id, 'admin_tree', marker, tree);
              popupContent.appendChild(actions);
              marker.bindPopup(popupContent);
              
              allTrees.push({ 
                lat: tree.lat, 
                lng: tree.lng, 
                source: 'admin_tree',
                data: tree,
                marker: marker
              });

              if (tree.treeType) {
                treeTypes.add(tree.treeType);
              }

              if (tree.area_name) {
                if (!areaCounts[tree.area_name]) {
                  areaCounts[tree.area_name] = 0;
                }
                areaCounts[tree.area_name]++;
              }
            }
          });
        }
      });

      updateTreeTypeFilter();

      if (geojsonLayer) {
        geojsonLayer.eachLayer(layer => {
          const feature = layer.feature;
          const areaName = feature.properties.name;
          const poly = turf.multiPolygon(feature.geometry.coordinates);

          const treesInArea = allTrees.filter(tree => isInPolygon(tree.lat, tree.lng, poly));
          const treeCount = treesInArea.length;
          const areaColor = getColorByTreeCount(treeCount);
          areaColors[areaName] = areaColor;
          
          layer.setStyle({
            fillColor: areaColor,
            color: '#000',
            weight: 1,
            opacity: 0.7,
            fillOpacity: 0.5
          });
          
          layer.bindPopup(
            '<b>' + areaName + '</b><br>' +
            'Số cây: ' + treeCount + '<br>' +
            'Diện tích: ' + (feature.properties.area_km2 ? feature.properties.area_km2.toFixed(2) : 'N/A') + ' km²' +
            '<div style="margin-top:5px;"><button onclick="window.showAreaDetails('' + areaName + '')" style="padding:3px 6px;background:#27ae60;color:white;border:none;border-radius:3px;cursor:pointer;">Chi tiết</button></div>'
          );
          
          const center = turf.centerOfMass(feature.geometry);
          const areaMarker = L.marker([center.geometry.coordinates[1], center.geometry.coordinates[0]], {
            icon: L.divIcon({
              html: '<div style="background-color: ' + areaColor + 
                    '; color: white; border-radius: 50%; width: 40px; height: 40px; ' + 
                    'display: flex; align-items: center; justify-content: center; font-weight: bold;">' + 
                    treeCount + '</div>',
              className: 'area-marker',
              iconSize: [40, 40]
            })
          });
          
          areaMarker.bindPopup(
            '<b>' + areaName + '</b><br>' +
            'Số cây: ' + treeCount + '<br>' +
            'Diện tích: ' + (feature.properties.area_km2 ? feature.properties.area_km2.toFixed(2) : 'N/A') + ' km²' +
            '<div style="margin-top:5px;"><button onclick="window.showAreaDetails('' + areaName + '')" style="padding:3px 6px;background:#27ae60;color:white;border:none;border-radius:3px;cursor:pointer;">Chi tiết</button></div>'
          );
          
          areaClusterGroup.addLayer(areaMarker);
          
          const areaTreeCluster = L.markerClusterGroup({
            iconCreateFunction: function(cluster) {
              const childCount = cluster.getChildCount();
              const color = areaColor;
              
              return L.divIcon({
                html: '<div style="background-color:' + color + '"><span>' + childCount + '</span></div>',
                className: 'marker-cluster',
                iconSize: L.point(40, 40)
              });
            },
            maxClusterRadius: 40,
            spiderfyOnMaxZoom: true,
            showCoverageOnHover: false
          });
          
          treesInArea.forEach(tree => {
            areaTreeCluster.addLayer(tree.marker);
          });
          
          treeClusters[areaName] = areaTreeCluster;
        });
      }
      
      updateStats();
      
      updateZoomView();
    }

    function updateTreeTypeFilter() {
      const filterSelect = document.getElementById('filterTreeType');
      filterSelect.innerHTML = '<option value="">Tất cả loại cây</option>';
      
      COMMON_TREE_TYPES.forEach(type => {
        const option = document.createElement('option');
        option.value = type;
        option.textContent = type;
        filterSelect.appendChild(option);
      });
      
      treeTypes.forEach(type => {
        if (!COMMON_TREE_TYPES.includes(type)) {
          const option = document.createElement('option');
          option.value = type;
          option.textContent = type;
          filterSelect.appendChild(option);
        }
      });
    }

    function filterTrees() {
      const typeFilter = document.getElementById('filterTreeType').value;
      const statusFilter = document.getElementById('filterTreeStatus').value;
      
      allTrees.forEach(tree => {
        if (map.hasLayer(tree.marker)) {
          map.removeLayer(tree.marker);
        }
      });
      
      allTrees.forEach(tree => {
        const matchesType = !typeFilter || (tree.data.treeType && tree.data.treeType === typeFilter);
        const matchesStatus = !statusFilter || (tree.data.status && tree.data.status === statusFilter);
        
        if (matchesType && matchesStatus) {
          if (!map.hasLayer(tree.marker)) {
            map.addLayer(tree.marker);
          }
        }
      });
    }

    function loadGeoJSON(data) {
      if (geojsonLayer) map.removeLayer(geojsonLayer);

      geojsonLayer = L.geoJSON(data, {
        style: function(feature) {
          return {
            fillColor: getColorByTreeCount(0),
            color: '#fff',
            weight: 5,
            opacity: 1,
            fillOpacity: 1
          };
        },
        onEachFeature: function(f, l) {
          const areaName = f.properties.name || 'Không tên';
          const areaSize = f.properties.area_km2 ? f.properties.area_km2.toFixed(2) : 'N/A';

          l.bindPopup(
            '<b>' + areaName + '</b><br>' +
            'Số cây: 0<br>' +
            'Diện tích: ' + areaSize + ' km²' +
            '<div style="margin-top:5px;"><button onclick="window.showAreaDetails('' + areaName + '')" style="padding:3px 6px;background:#27ae60;color:white;border:none;border-radius:3px;cursor:pointer;">Chi tiết</button></div>'
          );

          l.on('click', function() {
            showAreaInfo(f);
          });
        }
      }).addTo(map);

      loadTrees();
    }

    function showAllTrees() {
      currentArea = null;
      if (selectedAreaLayer) {
        map.removeLayer(selectedAreaLayer);
        selectedAreaLayer = null;
      }
      
      Object.values(treeClusters).forEach(cluster => {
        if (map.hasLayer(cluster)) {
          map.removeLayer(cluster);
        }
      });
      
      allTrees.forEach(tree => {
        if (!map.hasLayer(tree.marker)) {
          map.addLayer(tree.marker);
        }
      });
      
      if (allTrees.length > 0) {
        const group = new L.featureGroup(allTrees.map(t => t.marker));
        map.fitBounds(group.getBounds());
      }
    }

    window.showAreaDetails = function(areaName) {
      if (geojsonLayer) {
        geojsonLayer.eachLayer(layer => {
          if (layer.feature.properties.name === areaName) {
            showAreaInfo(layer.feature);
          }
        });
      }
    };

    map.on('zoomend', function() {
      currentZoom = map.getZoom();
      updateZoomView();
    });

    document.getElementById('toggleOSM').onclick = () => {
      if (!map.hasLayer(osm)) {
        map.removeLayer(satellite);
        osm.addTo(map);
        document.getElementById('toggleOSM').classList.add('active');
        document.getElementById('toggleSatellite').classList.remove('active');
      }
    };

    document.getElementById('toggleSatellite').onclick = () => {
      if (!map.hasLayer(satellite)) {
        map.removeLayer(osm);
        satellite.addTo(map);
        document.getElementById('toggleSatellite').classList.add('active');
        document.getElementById('toggleOSM').classList.remove('active');
      }
    };

    document.getElementById('toggleGeoJSON').onclick = e => {
      if (!geojsonLayer) return;
      if (map.hasLayer(geojsonLayer)) {
        map.removeLayer(geojsonLayer);
        e.target.classList.remove('active');
      } else {
        geojsonLayer.addTo(map);
        e.target.classList.add('active');
      }
    };

    document.getElementById('showAllTrees').onclick = e => {
      showAllTrees();
      e.target.classList.add('active');
    };

    document.getElementById('filterTreeType').addEventListener('change', filterTrees);
    document.getElementById('filterTreeStatus').addEventListener('change', filterTrees);

    window.receiveGeoJSON = function(data) {
      loadGeoJSON(data);
      return "GeoJSON loaded successfully";
    };
  </script>
  <script>
    window.addEventListener('message', function(event) {
      try {
        const geoJsonData = JSON.parse(event.data);
        if (typeof window.receiveGeoJSON === 'function') {
          window.receiveGeoJSON(geoJsonData);
        }
      } catch (e) {
        console.error('Invalid GeoJSON data', e);
      }
    });
  </script>
</body>
</html>
''';
}
