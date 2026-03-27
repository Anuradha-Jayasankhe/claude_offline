import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class ActivationSetupScreen extends StatefulWidget {
  const ActivationSetupScreen({super.key});

  @override
  State<ActivationSetupScreen> createState() => _ActivationSetupScreenState();
}

class _ActivationSetupScreenState extends State<ActivationSetupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _storeNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController(text: 'Sri Lanka');
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 2);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _storeNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPasswordController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _startTrial() async {
    final storeName = _storeNameController.text.trim();
    final ownerEmail = _ownerEmailController.text.trim();
    final ownerPassword = _ownerPasswordController.text.trim();

    if (storeName.isEmpty || ownerEmail.isEmpty || ownerPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store name, owner email, and password are required.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authService = context.read<AuthService>();
    final created = await authService.createTrialStoreOwner(
      storeName: storeName,
      ownerEmail: ownerEmail,
      ownerPassword: ownerPassword,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!created) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not create trial account. Email may already exist.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          initialEmail: ownerEmail,
          initialPassword: ownerPassword,
        ),
      ),
    );
  }

  Widget _buildLeftPane(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF142B7B), Color(0xFF2348BE)],
        ),
      ),
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 34),
          const Text(
            'Desktop Setup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create your store owner login and start a 7-day free trial.',
            style: TextStyle(color: Color(0xFFCEE0FF), fontSize: 20),
          ),
          const SizedBox(height: 38),
          const _SetupStep(
            index: 1,
            text: 'Activate this desktop for your store.',
          ),
          const SizedBox(height: 16),
          const _SetupStep(
            index: 2,
            text: 'Create owner credentials for store login.',
          ),
          const SizedBox(height: 16),
          const _SetupStep(
            index: 3,
            text: 'Sign in and start using your trial immediately.',
          ),
        ],
      ),
    );
  }

  Widget _buildRightPane(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activate This Device',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create your first store owner account with a 7-day trial.',
            style: TextStyle(fontSize: 16, color: Color(0xFF6C7285)),
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Sign In'),
              Tab(text: 'Activation Code'),
              Tab(text: 'Start 7-Day Trial'),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const Center(child: Text('Use the Login page to sign in.')),
                const Center(
                  child: Text('Activation code flow not implemented yet.'),
                ),
                SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _storeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Restaurant Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ownerEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Owner Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ownerPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Owner Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'This creates a store owner account with a 7-day trial. You can log in using these credentials immediately.',
                          style: TextStyle(color: Color(0xFF1A3FA5)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _startTrial,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create Trial & Continue to Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Center(
        child: SizedBox(
          width: 1200,
          height: 760,
          child: Row(
            children: [
              Expanded(flex: 47, child: _buildLeftPane(context)),
              const SizedBox(width: 22),
              Expanded(flex: 53, child: _buildRightPane(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  final int index;
  final String text;

  const _SetupStep({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white24,
          child: Text(
            index.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFD2DEFF), fontSize: 17),
          ),
        ),
      ],
    );
  }
}
