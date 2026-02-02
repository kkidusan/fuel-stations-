import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverHelpSupportPage extends StatelessWidget {
  const DriverHelpSupportPage({Key? key}) : super(key: key);

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch email';
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch phone call';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Help Center Section
            _buildSectionHeader('Help Center'),
            Card(
              child: Column(
                children: [
                  _buildHelpOption(
                    icon: Icons.question_answer,
                    title: 'FAQs',
                    subtitle: 'Frequently Asked Questions',
                    onTap: () {
                      // Navigate to FAQ page
                      // Navigator.push(context, MaterialPageRoute(builder: (context) => FAQPage()));
                    },
                  ),
                  _buildHelpOption(
                    icon: Icons.book,
                    title: 'User Guide',
                    subtitle: 'How to use the Driver App',
                    onTap: () {
                      // Open PDF guide or web page
                      _launchUrl('https://example.com/driver-guide');
                    },
                  ),
                  _buildHelpOption(
                    icon: Icons.video_library,
                    title: 'Video Tutorials',
                    subtitle: 'Watch step-by-step guides',
                    onTap: () {
                      // Navigate to video tutorials
                      _launchUrl('https://example.com/driver-tutorials');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Contact Support Section
            _buildSectionHeader('Contact Support'),
            Card(
              child: Column(
                children: [
                  _buildContactOption(
                    icon: Icons.chat,
                    title: 'Live Chat',
                    subtitle: 'Chat with support agent',
                    onTap: () {
                      // Open live chat
                      // Navigator.push(context, MaterialPageRoute(builder: (context) => LiveChatPage()));
                    },
                    badgeText: 'Online',
                    badgeColor: Colors.green,
                  ),
                  _buildContactOption(
                    icon: Icons.email,
                    title: 'Email Support',
                    subtitle: 'support@driverapp.com',
                    onTap: () => _launchEmail('support@driverapp.com'),
                  ),
                  _buildContactOption(
                    icon: Icons.phone,
                    title: 'Phone Support',
                    subtitle: '+1 (555) 123-4567',
                    onTap: () => _makePhoneCall('+15551234567'),
                  ),
                  _buildContactOption(
                    icon: Icons.forum,
                    title: 'Community Forum',
                    subtitle: 'Connect with other drivers',
                    onTap: () {
                      _launchUrl('https://example.com/driver-forum');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Troubleshooting Section
            _buildSectionHeader('Troubleshooting'),
            Card(
              child: Column(
                children: [
                  _buildTroubleshootOption(
                    title: 'App Not Working',
                    description: 'Check your internet connection and try restarting the app',
                    steps: ['Restart the app', 'Check internet', 'Update app to latest version'],
                  ),
                  _buildTroubleshootOption(
                    title: 'GPS Issues',
                    description: 'Ensure location services are enabled',
                    steps: ['Enable GPS', 'Check permissions', 'Restart device'],
                  ),
                  _buildTroubleshootOption(
                    title: 'Payment Problems',
                    description: 'Issues with payments or earnings',
                    steps: ['Check payment settings', 'Verify bank details', 'Contact support'],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Legal Section
            _buildSectionHeader('Legal'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.description, color: Colors.grey),
                    title: const Text('Terms of Service'),
                    onTap: () {
                      _launchUrl('https://example.com/terms');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip, color: Colors.grey),
                    title: const Text('Privacy Policy'),
                    onTap: () {
                      _launchUrl('https://example.com/privacy');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gavel, color: Colors.grey),
                    title: const Text('Driver Agreement'),
                    onTap: () {
                      _launchUrl('https://example.com/driver-agreement');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // About App Section
            _buildSectionHeader('About'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.drive_eta,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Driver App',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Version 2.1.0 • Build 210',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The Driver App helps delivery drivers connect with gas stations '
                      'for efficient fuel delivery services. Manage your deliveries, '
                      'track earnings, and find nearby stations all in one place.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          color: Colors.blue,
                          onPressed: () {
                            showLicensePage(context: context);
                          },
                        ),
                        const Text('Licenses'),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.share),
                          color: Colors.blue,
                          onPressed: () {
                            // Share app
                            // _shareApp();
                          },
                        ),
                        const Text('Share App'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildHelpOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Row(
        children: [
          Text(title),
          if (badgeText != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildTroubleshootOption({
    required String title,
    required String description,
    required List<String> steps,
  }) {
    return ExpansionTile(
      leading: const Icon(Icons.build, color: Colors.orange),
      title: Text(title),
      subtitle: Text(description),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}