import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import '../../widgets/phone_input.dart';

class DriverEditProfilePage extends StatefulWidget {
  const DriverEditProfilePage({super.key});

  @override
  State<DriverEditProfilePage> createState() => _DriverEditProfilePageState();
}

class _DriverEditProfilePageState extends State<DriverEditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late PhoneController _phone;
  late TextEditingController _plateController;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phone = PhoneController();
    _plateController = TextEditingController();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('No authenticated user found');

      final res = await AppApi.myProfile();
      final data = Map<String, dynamic>.from(res['user'] as Map? ?? {});

      final name = (data['display_name'] as String?)?.trim();
      final phone = ((data['phone'] ?? data['phone_number']) as String?)?.trim();
      final plate = (data['license_plate'] as String?)?.trim();

      _nameController.text = (name != null && name.isNotEmpty)
          ? name
          : (user.displayName?.trim() ?? '');
      _phone.setFromStored(phone);
      _plateController.text = plate ?? '';
    } on ApiException catch (e) {
      debugPrint('Error loading driver profile: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      debugPrint('Error loading driver profile: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load profile data';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final res = await AppApi.updateProfile({
        'display_name': _nameController.text.trim(),
        'phone': _phone.fullPhone,
        'license_plate': _plateController.text.trim().toUpperCase(),
      });

      final updatedUser = res['user'];
      if (updatedUser is Map<String, dynamic>) {
        AuthService.updateCachedUser(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save profile. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phone.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Driver Profile'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header hint
                      Card(
                        elevation: 0,
                        color: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: const [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Update your personal information below',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name / Driver Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.trim().length < 3) {
                            return 'Name is too short';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Phone field
                      PhoneField(
                        controller: _phone,
                        label: 'Phone Number',
                        hint: '9xx xxx xxx',
                        borderRadius: 12,
                        fillColor: Colors.grey.shade50,
                      ),

                      const SizedBox(height: 20),

                      // Plate number field
                      TextFormField(
                        controller: _plateController,
                        decoration: InputDecoration(
                          labelText: 'Vehicle Plate Number (Targa)',
                          prefixIcon: const Icon(Icons.directions_car_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          hintText: 'e.g. AA 12345',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          UpperCaseTextFormatter(),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Plate number is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 40),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton.icon(
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              onPressed: _isSaving ? null : _saveProfile,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      const Center(
                        child: Text(
                          'Changes will be reflected immediately',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// Helper formatter to force uppercase input
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}