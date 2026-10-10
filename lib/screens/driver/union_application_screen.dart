import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import '../../widgets/phone_input.dart';

class UnionApplicationScreen extends StatefulWidget {
  const UnionApplicationScreen({super.key});

  @override
  State<UnionApplicationScreen> createState() => _UnionApplicationScreenState();
}

class _UnionApplicationScreenState extends State<UnionApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phone = PhoneController();
  final _licenseNumberController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _experienceController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isLoading = false;
  bool _hasApplied = false;

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  Future<void> _checkApplicationStatus() async {
    try {
      final app = await AppApi.myUnionApplication();
      if (app == null || !mounted) return;

      setState(() {
        _hasApplied = true;
        _nameController.text = app['name']?.toString() ?? '';
        _phone.setFromStored(app['phone']?.toString());
        _licenseNumberController.text = app['license_number']?.toString() ?? '';
        _plateNumberController.text = app['plate_number']?.toString() ?? '';
        _experienceController.text = app['experience']?.toString() ?? '';
        _reasonController.text = app['reason']?.toString() ?? '';
      });
    } catch (e) {
      debugPrint('Error checking union application: $e');
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('No user logged in');

      await AppApi.submitUnionApplication({
        'email': user.email,
        'name': _nameController.text.trim(),
        'phone': _phone.fullPhone,
        'license_number': _licenseNumberController.text.trim(),
        'plate_number': _plateNumberController.text.trim(),
        'experience': _experienceController.text.trim(),
        'reason': _reasonController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _hasApplied = true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
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
        title: const Text('Union Membership Application'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_hasApplied)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You have already applied. Your application is being reviewed.',
                            style: TextStyle(color: Colors.blue.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                PhoneField(
                  controller: _phone,
                  label: 'Phone Number',
                  hint: '9xx xxx xxx',
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _licenseNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Driver License Number',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your license number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _plateNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Plate Number',
                    prefixIcon: Icon(Icons.confirmation_number),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your plate number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _experienceController,
                  decoration: const InputDecoration(
                    labelText: 'Years of Driving Experience',
                    prefixIcon: Icon(Icons.timelapse),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your experience';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Why do you want to join the union?',
                    prefixIcon: Icon(Icons.question_answer),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your reason';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton(
                    onPressed: _hasApplied ? null : _submitApplication,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(
                      _hasApplied ? 'Application Submitted' : 'Submit Application',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phone.dispose();
    _licenseNumberController.dispose();
    _plateNumberController.dispose();
    _experienceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}