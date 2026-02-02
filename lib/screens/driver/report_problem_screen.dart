import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  String? _selectedStationId;
  String? _selectedStationName;
  String? _problemType;
  final _descriptionController = TextEditingController();
  final List<String> _problemTypes = [
    'Fuel Quality Issue',
    'Price Discrepancy',
    'Service Attitude',
    'Equipment Problem',
    'Hygiene Concern',
    'Safety Issue',
    'Other'
  ];

  bool _isLoading = false;
  List<Map<String, dynamic>> _stations = [];

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'station')
          .get();

      if (mounted) {
        setState(() {
          _stations = query.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['stationName']?.toString() ?? 'Unknown Station',
              'address': data['address']?.toString() ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading stations: $e');
    }
  }

  Future<void> _submitReport() async {
    if (_selectedStationId == null || _problemType == null || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      await FirebaseFirestore.instance
          .collection('problem_reports')
          .add({
            'userId': user.uid,
            'userEmail': user.email,
            'stationId': _selectedStationId,
            'stationName': _selectedStationName,
            'problemType': _problemType,
            'description': _descriptionController.text.trim(),
            'status': 'pending',
            'reportedAt': FieldValue.serverTimestamp(),
            'resolved': false,
          });

      // Notify station owner (optional - could use cloud functions)
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
            'userId': _selectedStationId,
            'title': 'New Problem Report',
            'message': 'A driver reported: $_problemType',
            'type': 'problem_report',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Problem reported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Problem'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Select Station
              const Text(
                'Select Station',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedStationId,
                decoration: InputDecoration(
                  hintText: 'Choose a station',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.local_gas_station),
                ),
                items: _stations.map((station) {
                  return DropdownMenuItem<String>(
                    value: station['id'],
                    child: Text(
                      '${station['name']} - ${station['address']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStationId = value;
                    _selectedStationName = _stations
                        .firstWhere((s) => s['id'] == value)['name'];
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a station' : null,
              ),
              const SizedBox(height: 24),

              // Problem Type
              const Text(
                'Problem Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _problemTypes.map((type) {
                  final isSelected = _problemType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    selectedColor: Colors.blue.withOpacity(0.2),
                    onSelected: (selected) {
                      setState(() {
                        _problemType = selected ? type : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe the problem in detail...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  onPressed: _submitReport,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text(
                    'Submit Report',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}