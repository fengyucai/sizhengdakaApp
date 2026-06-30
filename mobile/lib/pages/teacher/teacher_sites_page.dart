import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/location_service.dart';
import 'site_map_picker_page.dart';

class TeacherSitesPage extends StatefulWidget {
  const TeacherSitesPage({super.key});

  @override
  State<TeacherSitesPage> createState() => _TeacherSitesPageState();
}

class _TeacherSitesPageState extends State<TeacherSitesPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.getManageSites();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _show(_friendlyError(e), Colors.red);
    }
  }

  Future<void> _editSite([Map<String, dynamic>? site]) async {
    final result = await showModalBottomSheet<_SiteFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SiteFormSheet(site: site),
    );
    if (result == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      if (site == null) {
        await ApiService.createManageSite(
          name: result.name,
          type: result.type,
          latitude: result.latitude,
          longitude: result.longitude,
          radiusMeters: result.radiusMeters,
          address: result.address,
        );
        _show('打卡点已创建', Colors.green);
      } else {
        await ApiService.updateManageSite(
          id: (site['id'] as num).toInt(),
          name: result.name,
          type: result.type,
          latitude: result.latitude,
          longitude: result.longitude,
          radiusMeters: result.radiusMeters,
          address: result.address,
        );
        _show('打卡点已更新', Colors.green);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleSite(Map<String, dynamic> site) async {
    final active = site['status'] == 'ACTIVE';
    final action = active ? '停用' : '启用';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action打卡点'),
        content: Text('确认$action“${site['name']}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      final id = (site['id'] as num).toInt();
      if (active) {
        await ApiService.disableManageSite(id);
      } else {
        await ApiService.enableManageSite(id);
      }
      await _load();
      if (!mounted) return;
      _show('打卡点已$action', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteSite(Map<String, dynamic> site) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除打卡点'),
        content: Text(
          '确认删除“${site['name']}”？\n\n已有签到或课堂历史记录的打卡点不能删除，请使用停用保留历史数据。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ApiService.deleteManageSite((site['id'] as num).toInt());
      await _load();
      if (!mounted) return;
      _show('打卡点已删除', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  void _show(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _items.where((item) => item['status'] == 'ACTIVE').length;
    return Scaffold(
      appBar: AppBar(
        title: Text('打卡点管理 ($activeCount/${_items.length})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/teacher/home'),
        ),
        actions: [
          IconButton(
            tooltip: '新增',
            onPressed: _submitting ? null : () => _editSite(),
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return FilledButton.icon(
                      onPressed: _submitting ? null : () => _editSite(),
                      icon: const Icon(Icons.add),
                      label: const Text('新增打卡点'),
                    );
                  }
                  final item = _items[index - 1];
                  final active = item['status'] == 'ACTIVE';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['name']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              Chip(
                                label: Text(active ? '启用' : '停用'),
                                backgroundColor: active
                                    ? Colors.green.shade50
                                    : Colors.grey.shade200,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('类型：${_typeLabel('${item['type']}')}'),
                          Text('坐标：${item['latitude']}, ${item['longitude']}'),
                          Text('半径：${item['radiusMeters']} 米'),
                          Text(
                              '地址：${(item['address'] ?? '').toString().isEmpty ? '未填写' : item['address']}'),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed:
                                    _submitting ? null : () => _editSite(item),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('编辑'),
                              ),
                              TextButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : () => _toggleSite(item),
                                icon: Icon(active
                                    ? Icons.block_outlined
                                    : Icons.check_circle_outline),
                                label: Text(active ? '停用' : '启用'),
                              ),
                              TextButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : () => _deleteSite(item),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('删除'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _typeLabel(String type) {
    if (type == 'DORM') return '宿舍';
    if (type == 'CLASSROOM') return '教室';
    if (type == 'INTERNSHIP') return '实习单位';
    return type;
  }
}

class _SiteFormSheet extends StatefulWidget {
  const _SiteFormSheet({this.site});

  final Map<String, dynamic>? site;

  @override
  State<_SiteFormSheet> createState() => _SiteFormSheetState();
}

class _SiteFormSheetState extends State<_SiteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _locationService = LocationService();
  late final TextEditingController _nameController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _radiusController;
  late final TextEditingController _addressController;
  String _type = 'DORM';
  bool _working = false;

  @override
  void initState() {
    super.initState();
    final site = widget.site;
    _type = '${site?['type'] ?? 'DORM'}';
    _nameController = TextEditingController(text: '${site?['name'] ?? ''}');
    _latController = TextEditingController(text: '${site?['latitude'] ?? ''}');
    _lngController = TextEditingController(text: '${site?['longitude'] ?? ''}');
    _radiusController =
        TextEditingController(text: '${site?['radiusMeters'] ?? 300}');
    _addressController =
        TextEditingController(text: '${site?['address'] ?? ''}');
  }

  Future<void> _geocode() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _show('请先填写详细地址', Colors.orange);
      return;
    }
    setState(() => _working = true);
    try {
      final result = await ApiService.geocodeAddress(address: address);
      _latController.text = '${result['latitude'] ?? ''}';
      _lngController.text = '${result['longitude'] ?? ''}';
      if (!mounted) return;
      _show('地址已解析，可信度 ${result['confidence'] ?? '-'}', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _working = true);
    try {
      final location = await _locationService.getCurrentLocation(
        forceRefresh: true,
        cacheMaxAge: const Duration(minutes: 10),
        cacheMaxAccuracy: 120,
      );
      final pos = location.position;
      _latController.text = pos.latitude.toStringAsFixed(7);
      _lngController.text = pos.longitude.toStringAsFixed(7);
      final nativeAddress = _addressLine(location.address ?? {});
      if (nativeAddress.isNotEmpty) {
        _addressController.text = nativeAddress;
      } else {
        try {
          final address = await ApiService.reverseGeocode(
            lat: pos.latitude,
            lng: pos.longitude,
          );
          final formatted = _addressLine(address);
          if (formatted.isNotEmpty) _addressController.text = formatted;
        } catch (_) {}
      }
      if (!mounted) return;
      _show('已使用当前位置填充坐标和详细地址', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickOnMap() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final result = await Navigator.of(context).push<SiteMapPickResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SiteMapPickerPage(
          initialLatitude: lat,
          initialLongitude: lng,
          initialAddress: _addressController.text.trim(),
        ),
      ),
    );
    if (result == null || !mounted) return;
    _latController.text = result.latitude.toStringAsFixed(7);
    _lngController.text = result.longitude.toStringAsFixed(7);
    if (result.address.isNotEmpty) {
      _addressController.text = result.address;
    }
    _show('已从地图选点填入坐标和详细地址', Colors.green);
  }


  Future<void> _reverseCurrentCoordinates() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      _show('请先填写有效经纬度', Colors.orange);
      return;
    }
    setState(() => _working = true);
    try {
      final address = await ApiService.reverseGeocode(lat: lat, lng: lng);
      final formatted = _addressLine(address);
      if (formatted.isNotEmpty) _addressController.text = formatted;
      if (!mounted) return;
      _show('已根据坐标反查并填入详细地址', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_SiteFormResult(
      name: _nameController.text.trim(),
      type: _type,
      latitude: double.parse(_latController.text.trim()),
      longitude: double.parse(_lngController.text.trim()),
      radiusMeters: int.parse(_radiusController.text.trim()),
      address: _addressController.text.trim(),
    ));
  }

  void _show(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.site == null ? '新增打卡点' : '编辑打卡点',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请填写名称' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _type,
                decoration: const InputDecoration(
                  labelText: '类型',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'DORM', child: Text('宿舍')),
                  DropdownMenuItem(value: 'CLASSROOM', child: Text('教室')),
                  DropdownMenuItem(value: 'INTERNSHIP', child: Text('实习单位')),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'DORM'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '详细地址',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: '按地址解析坐标',
                    onPressed: _working ? null : _geocode,
                    icon: _working
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.travel_explore_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _working ? null : _pickOnMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('打开地图选点'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('使用当前位置'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '纬度',
                        border: OutlineInputBorder(),
                      ),
                      validator: _numberValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '经度',
                        border: OutlineInputBorder(),
                      ),
                      validator: _numberValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _working ? null : _reverseCurrentCoordinates,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('按坐标反查详细地址'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _radiusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '半径（米）',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final radius = int.tryParse(value ?? '');
                  if (radius == null) return '请填写半径';
                  if (radius < 20 || radius > 5000) {
                    return '半径需在 20-5000 米';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : _submit,
                  child: Text(widget.site == null ? '创建' : '保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _numberValidator(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null ? '请填写有效数字' : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}

class _SiteFormResult {
  const _SiteFormResult({
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.address,
  });

  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String address;
}
