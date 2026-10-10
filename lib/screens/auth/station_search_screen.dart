import 'package:flutter/material.dart';

import '../../services/app_api.dart';

/// Full-screen station search.
///
/// Opened from the login screen when its search field is tapped. It shows the
/// active stations and filters them live as the user types. Choosing a station
/// pops its map back to the caller (the login screen then centres the map on it
/// and drops a red pin); going back without choosing pops `null`.
class StationSearchScreen extends StatefulWidget {
  const StationSearchScreen({
    super.key,
    this.initialStations = const [],
    this.language = 'en',
  });

  /// Stations already loaded by the caller — shown instantly (and refreshed
  /// from the network in the background is skipped while these are present).
  final List<Map<String, dynamic>> initialStations;

  /// 'en' | 'am' — used for the built-in labels.
  final String language;

  @override
  State<StationSearchScreen> createState() => _StationSearchScreenState();
}

class _StationSearchScreenState extends State<StationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;

  static const Color _accent = Color(0xFF32CD32);
  static const Color _ink = Color(0xFF1C1C1E);

  @override
  void initState() {
    super.initState();
    _stations = List<Map<String, dynamic>>.from(widget.initialStations);
    _results = _stations;
    _controller.addListener(_onChanged);

    if (_stations.isNotEmpty) {
      _loading = false;
    } else {
      _loadStations();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _t(String en, String am) => widget.language == 'en' ? en : am;

  /// Loads the active stations straight from the backend when the caller
  /// didn't hand any over.
  Future<void> _loadStations() async {
    try {
      final rows = await AppApi.locations();
      final List<Map<String, dynamic>> loaded = [];
      for (final data in rows) {
        if (data['isActive'] == false) continue;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final address = (data['address'] ?? data['city'])?.toString().trim();
        loaded.add({
          'id': data['id']?.toString(),
          'name': data['name'] as String? ?? 'Station',
          'address': (address == null || address.isEmpty) ? null : address,
          'lat': lat,
          'lng': lng,
        });
      }
      if (!mounted) return;
      setState(() {
        _stations = loaded;
        _loading = false;
        _applyFilter();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stations = [];
        _loading = false;
        _applyFilter();
      });
    }
  }

  void _onChanged() => setState(_applyFilter);

  void _applyFilter() {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) {
      _results = _stations;
    } else {
      _results = _stations
          .where((s) => (s['name'] as String).toLowerCase().contains(q))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F8F4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: _t('Search station...', 'ጣቢያ ይፈልጉ...'),
              prefixIcon: const Icon(Icons.search, color: _ink),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, color: _ink),
                      onPressed: () => _controller.clear(),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_results.isEmpty) {
      final hasQuery = _controller.text.trim().isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 72, color: Color(0xFFB0B8B2)),
              const SizedBox(height: 16),
              Text(
                hasQuery
                    ? _t('No stations found', 'ጣቢያ አልተገኘም')
                    : _t('No stations available', 'ምንም ጣቢያ የለም'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B6B6B),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
      itemBuilder: (_, i) => _resultTile(_results[i]),
    );
  }

  Widget _resultTile(Map<String, dynamic> s) {
    final address = s['address'] as String?;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const CircleAvatar(
        radius: 22,
        backgroundColor: Color(0xFFE6F7E9),
        child: Icon(Icons.local_gas_station, color: _accent),
      ),
      title: Text(
        s['name'] as String,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, color: _ink),
      ),
      subtitle: (address == null || address.isEmpty)
          ? null
          : Text(address, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF9AA39C)),
      onTap: () => Navigator.of(context).pop(s),
    );
  }
}
