import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StationHelpSupportPage extends StatelessWidget {
  const StationHelpSupportPage({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Station Support Request');
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Station Management Help ────────────────────────────────
            _buildSectionHeader('Station Management Help'),
            _buildHelpOption(
              icon: Icons.inventory,
              title: 'Inventory Management',
              subtitle: 'How to manage fuel inventory and stock',
              onTap: () {
                _launchUrl('https://example.com/station-inventory-guide');
              },
            ),
            _buildDivider(),
            _buildHelpOption(
              icon: Icons.schedule,
              title: 'Pre-order Management',
              subtitle: 'Handling customer pre-orders',
              onTap: () {
                _launchUrl('https://example.com/preorder-management');
              },
            ),
            _buildDivider(),
            _buildHelpOption(
              icon: Icons.attach_money,
              title: 'Pricing & Payments',
              subtitle: 'Setting prices and managing payments',
              onTap: () {
                _launchUrl('https://example.com/station-pricing-guide');
              },
            ),
            _buildDivider(),
            _buildHelpOption(
              icon: Icons.delivery_dining,
              title: 'Driver Management',
              subtitle: 'Working with delivery drivers',
              onTap: () {
                _launchUrl('https://example.com/driver-management');
              },
            ),

            const SizedBox(height: 16),

            // ── Contact Support ───────────────────────────────────────
            _buildSectionHeader('Contact Support'),
            _buildContactOption(
              icon: Icons.chat,
              title: '24/7 Support Chat',
              subtitle: 'Instant chat with support team',
              onTap: () {
                // Open live chat
              },
              badgeText: '24/7',
              badgeColor: Colors.green,
            ),
            _buildDivider(),
            _buildContactOption(
              icon: Icons.email,
              title: 'Email Support',
              subtitle: 'station-support@fuelapp.com',
              onTap: () => _launchEmail('station-support@fuelapp.com'),
            ),
            _buildDivider(),
            _buildContactOption(
              icon: Icons.phone,
              title: 'Business Support',
              subtitle: '+1 (555) 987-6543',
              onTap: () => _makePhoneCall('+15559876543'),
            ),
            _buildDivider(),
            _buildContactOption(
              icon: Icons.business,
              title: 'Account Manager',
              subtitle: 'Dedicated station account manager',
              onTap: () => _launchEmail('account-manager@fuelapp.com'),
            ),

            const SizedBox(height: 16),

            // ── Technical Issues ──────────────────────────────────────
            _buildSectionHeader('Technical Issues'),
            _buildTroubleshootOption(
              title: 'App Connectivity',
              description: 'Issues connecting to the server',
              steps: [
                'Check internet connection',
                'Restart the app',
                'Update to latest version',
                'Clear app cache',
              ],
            ),
            _buildDivider(),
            _buildTroubleshootOption(
              title: 'Payment Processing',
              description: 'Problems with payment transactions',
              steps: [
                'Verify payment gateway',
                'Check transaction logs',
                'Contact support if issue persists',
              ],
            ),
            _buildDivider(),
            _buildTroubleshootOption(
              title: 'Inventory Sync Issues',
              description: 'Fuel levels not updating properly',
              steps: [
                'Check network connection',
                'Manually sync inventory',
                'Contact technical support',
              ],
            ),
            _buildDivider(),
            _buildTroubleshootOption(
              title: 'Driver App Issues',
              description: 'Problems with driver connections',
              steps: [
                'Check driver app status',
                'Verify driver credentials',
                'Reset driver connections',
              ],
            ),

            const SizedBox(height: 16),

            // ── Business Resources ────────────────────────────────────
            _buildSectionHeader('Business Resources'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bar_chart, color: Colors.purple),
              title: const Text('Analytics Guide'),
              subtitle: const Text('Understanding station analytics'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                _launchUrl('https://example.com/station-analytics-guide');
              },
            ),
            _buildDivider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.trending_up, color: Colors.green),
              title: const Text('Growth Strategies'),
              subtitle: const Text('Tips to grow your station business'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                _launchUrl('https://example.com/station-growth');
              },
            ),
            _buildDivider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.group, color: Colors.blue),
              title: const Text('Customer Retention'),
              subtitle: const Text('Keeping customers coming back'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                _launchUrl('https://example.com/customer-retention');
              },
            ),
            _buildDivider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.security, color: Colors.orange),
              title: const Text('Safety Guidelines'),
              subtitle: const Text('Station safety protocols'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                _launchUrl('https://example.com/station-safety');
              },
            ),

            const SizedBox(height: 16),

            // ── Legal & Compliance ────────────────────────────────────
            _buildSectionHeader('Legal & Compliance'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description, color: Colors.grey),
              title: const Text('Station Agreement'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                _launchUrl('https://example.com/station-agreement');
              },
            ),
            _buildDivider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip, color: Colors.grey),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                _launchUrl('https://example.com/privacy-policy');
              },
            ),
            _buildDivider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.gavel, color: Colors.grey),
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                _launchUrl('https://example.com/terms-of-service');
              },
            ),
            _buildDivider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.assignment, color: Colors.grey),
              title: const Text('Compliance Documents'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                _launchUrl('https://example.com/compliance-docs');
              },
            ),

            const SizedBox(height: 16),

            // ── About Station App (no card bg) ────────────────────────
            _buildSectionHeader('About Station App'),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF256af4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_gas_station,
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
                              'Station Management App',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Version 3.2.1 • Build 321',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The Station App helps fuel station owners manage their business efficiently. '
                    'Track inventory, handle pre-orders, manage drivers, and analyze station performance '
                    'all from one platform.',
                    style: TextStyle(
                      color: Colors.grey[700],
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 20),
                        color: Colors.blue,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          showLicensePage(context: context);
                        },
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Licenses',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const Spacer(),
                      const Flexible(
                        child: Text(
                          'Share App',
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        color: Colors.blue,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          // Share app
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Quick Action Buttons (overflow-proof) ─────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.feedback, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Send Feedback'),
                    ),
                    onPressed: () => _launchEmail('feedback@fuelapp.com'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Rate App'),
                    ),
                    onPressed: () {
                      // Launch app store
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  /// Thin separator used between plain list items (no card background).
  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 0.6);
  }

  Widget _buildHelpOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: Colors.blue, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
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
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: Colors.green, size: 22),
      title: Row(
        children: [
          // Flexible title so the badge never overflows the row.
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 15),
            ),
          ),
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
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildTroubleshootOption({
    required String title,
    required String description,
    required List<String> steps,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 36, bottom: 12, top: 4),
      dense: true,
      leading: const Icon(Icons.build, color: Colors.orange, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        description,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      children: [
        Column(
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
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}