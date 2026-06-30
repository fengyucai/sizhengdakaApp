import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/native_capability_config.dart';
import '../../services/location_service.dart';

class SiteMapPickResult {
  const SiteMapPickResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;
}

class SiteMapPickerPage extends StatefulWidget {
  const SiteMapPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  @override
  State<SiteMapPickerPage> createState() => _SiteMapPickerPageState();
}

class _SiteMapPickerPageState extends State<SiteMapPickerPage> {
  final _locationService = LocationService();
  final _searchController = TextEditingController();
  late final WebViewController _webViewController;

  double _latitude = 26.8891000;
  double _longitude = 112.5942000;
  String _address = '';
  bool _loading = true;
  bool _resolving = false;
  bool _mapReady = false;
  bool _satelliteEnabled = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude ?? _latitude;
    _longitude = widget.initialLongitude ?? _longitude;
    _address = widget.initialAddress ?? '';
    _searchController.text = _address;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'MapPicker',
        onMessageReceived: (message) {
          _handleMapMessage(message.message);
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _mapReady = true;
          });
        },
        onWebResourceError: (error) {
          if (!mounted || error.isForMainFrame != true) return;
          setState(() {
            _loading = false;
            _error = '地图加载失败：${error.description}';
          });
        },
      ));
    _loadMap();
    _reverseSelectedCoordinates();
  }

  Future<void> _loadMap() async {
    const key = NativeCapabilityConfig.amapAndroidKey;
    if (key.isEmpty) {
      setState(() {
        _loading = false;
        _error = '未配置高德地图 Key，无法打开地图选点';
      });
      return;
    }
    await _webViewController.loadHtmlString(
      _mapHtml(key),
      baseUrl: 'https://webapi.amap.com/',
    );
  }

  void _handleMapMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = (data['type'] ?? 'picked').toString();
      if (type == 'error') {
        setState(() => _error = (data['message'] ?? '地图服务异常').toString());
        return;
      }
      if (type == 'resolved') {
        _applyAddress(data['address']?.toString() ?? '');
        return;
      }
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      final address = data['address']?.toString() ?? '';
      setState(() {
        _latitude = lat;
        _longitude = lng;
        if (address.isNotEmpty) {
          _address = address;
          _searchController.text = address;
        }
      });
    } catch (_) {
      // Ignore malformed messages from the WebView bridge.
    }
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      final location = await _locationService.getCurrentLocation(
        forceRefresh: true,
        cacheMaxAge: const Duration(minutes: 10),
        cacheMaxAccuracy: 120,
      );
      final pos = location.position;
      final address = _addressLine(location.address ?? {});
      await _moveMap(pos.latitude, pos.longitude);
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        if (address.isNotEmpty) {
          _address = address;
          _searchController.text = address;
        }
      });
      await _reverseSelectedCoordinates();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _searchAddress() async {
    final address = _searchController.text.trim();
    if (address.isEmpty) {
      setState(() => _error = '请先输入要搜索的地址或地点名称');
      return;
    }
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      await _webViewController.runJavaScript(
        'searchAddress(${jsonEncode(address)});',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _reverseSelectedCoordinates() async {
    setState(() => _resolving = true);
    try {
      await _webViewController.runJavaScript(
        'reverseAt($_longitude, $_latitude);',
      );
    } catch (_) {
      // The coordinates are still usable even if reverse geocoding fails.
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _moveMap(double lat, double lng) async {
    if (!_mapReady) return;
    await _webViewController.runJavaScript('moveTo($lng, $lat);');
  }

  Future<void> _toggleSatelliteLayer() async {
    if (!_mapReady) return;
    final next = !_satelliteEnabled;
    await _webViewController.runJavaScript(
      'setSatellite(${next ? 'true' : 'false'});',
    );
    if (!mounted) return;
    setState(() => _satelliteEnabled = next);
  }

  void _confirm() {
    Navigator.of(context).pop(SiteMapPickResult(
      latitude: _latitude,
      longitude: _longitude,
      address: _address,
    ));
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  void _applyAddress(String address) {
    if (address.isEmpty || !mounted) return;
    setState(() {
      _address = address;
      _searchController.text = address;
    });
  }

  String _addressLine(Map<String, dynamic> address) {
    final formatted = (address['formattedAddress'] ?? '').toString();
    if (formatted.isNotEmpty) return formatted;
    final parts = [
      address['province'],
      address['city'],
      address['district'],
      address['town'],
      address['street'],
      address['streetNumber'],
    ]
        .map((part) => part?.toString() ?? '')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.join('');
  }

  String _mapHtml(String key) {
    final escapedKey = const HtmlEscape().convert(key);
    final lng = _longitude.toStringAsFixed(7);
    final lat = _latitude.toStringAsFixed(7);
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="initial-scale=1.0, user-scalable=no, width=device-width">
  <style>
    html, body, #container { width: 100%; height: 100%; margin: 0; padding: 0; }
    .center-pin {
      position: absolute;
      z-index: 10;
      left: 50%;
      top: 50%;
      width: 28px;
      height: 28px;
      margin-left: -14px;
      margin-top: -28px;
      pointer-events: none;
      filter: drop-shadow(0 2px 4px rgba(0,0,0,.35));
    }
    .center-pin:before {
      content: "";
      position: absolute;
      left: 4px;
      top: 0;
      width: 20px;
      height: 20px;
      border-radius: 50% 50% 50% 0;
      background: #2563eb;
      transform: rotate(-45deg);
    }
    .center-pin:after {
      content: "";
      position: absolute;
      left: 10px;
      top: 6px;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: white;
    }
  </style>
  <script src="https://webapi.amap.com/maps?v=2.0&key=$escapedKey&plugin=AMap.ToolBar,AMap.Scale,AMap.Geocoder"></script>
</head>
<body>
  <div id="container"></div>
  <div class="center-pin"></div>
  <script>
    var map = new AMap.Map('container', {
      zoom: 17,
      center: [$lng, $lat],
      resizeEnable: true,
      viewMode: '2D'
    });
    var satellite = new AMap.TileLayer.Satellite();
    var roadNet = new AMap.TileLayer.RoadNet();
    map.add([satellite, roadNet]);
    var geocoder = new AMap.Geocoder({ city: '全国' });
    map.addControl(new AMap.ToolBar({ position: 'RB' }));
    map.addControl(new AMap.Scale());

    function addressText(result) {
      if (!result || !result.regeocode) return '';
      var regeocode = result.regeocode;
      if (regeocode.formattedAddress) return regeocode.formattedAddress;
      var comp = regeocode.addressComponent || {};
      return [
        comp.province,
        comp.city,
        comp.district,
        comp.township,
        comp.street,
        comp.streetNumber
      ].filter(Boolean).join('');
    }

    function postCenter() {
      var center = map.getCenter();
      reverseAt(center.lng, center.lat);
    }

    function postPoint(lng, lat, address) {
      MapPicker.postMessage(JSON.stringify({
        type: 'picked',
        lng: lng,
        lat: lat,
        address: address || ''
      }));
    }

    function postError(message) {
      MapPicker.postMessage(JSON.stringify({ type: 'error', message: message }));
    }

    function reverseAt(lng, lat) {
      geocoder.getAddress([lng, lat], function(status, result) {
        if (status === 'complete' && result && result.regeocode) {
          postPoint(lng, lat, addressText(result));
        } else {
          postPoint(lng, lat, '');
        }
      });
    }

    map.on('click', function(e) {
      map.setCenter(e.lnglat);
      postCenter();
    });
    map.on('moveend', postCenter);
    map.on('zoomend', postCenter);

    function moveTo(lng, lat) {
      map.setZoomAndCenter(17, [lng, lat]);
      postCenter();
    }

    function searchAddress(keyword) {
      geocoder.getLocation(keyword, function(status, result) {
        if (status === 'complete' && result.geocodes && result.geocodes.length) {
          var first = result.geocodes[0];
          map.setZoomAndCenter(18, first.location);
          reverseAt(first.location.lng, first.location.lat);
        } else {
          postError('未搜索到该位置，请换一个更完整的地址或直接拖动地图选点');
        }
      });
    }

    function setSatellite(enabled) {
      if (enabled) {
        map.add([satellite, roadNet]);
      } else {
        map.remove([satellite, roadNet]);
      }
    }

    setTimeout(postCenter, 400);
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图选点'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('使用此位置'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchAddress(),
                    decoration: const InputDecoration(
                      hintText: '搜索学校、楼栋、宿舍、企业地址',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: '搜索',
                  onPressed: _resolving ? null : _searchAddress,
                  icon: const Icon(Icons.travel_explore_outlined),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: _satelliteEnabled ? '切换普通地图' : '切换卫星地图',
                  onPressed: _mapReady ? _toggleSatelliteLayer : null,
                  icon: Icon(_satelliteEnabled
                      ? Icons.satellite_alt_outlined
                      : Icons.map_outlined),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: '定位到当前位置',
                  onPressed: _resolving ? null : _moveToCurrentLocation,
                  icon: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_error == null)
                  WebViewWidget(controller: _webViewController)
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  ),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _address.isEmpty ? '拖动地图或点击地图选择位置' : _address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '纬度 ${_latitude.toStringAsFixed(7)} · 经度 ${_longitude.toStringAsFixed(7)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check),
                      label: const Text('使用此位置'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
