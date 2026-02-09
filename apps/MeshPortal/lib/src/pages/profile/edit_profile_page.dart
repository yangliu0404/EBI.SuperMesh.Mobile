import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Edit profile form page.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _companyController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _companyController = TextEditingController(text: user?.company ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(
        title: 'Edit Profile',
        backgroundColor: EbiColors.secondaryCyan,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          EbiTextField(
            controller: _nameController,
            labelText: 'Name',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          EbiTextField(
            controller: _emailController,
            labelText: 'Email',
            prefixIcon: Icons.email_outlined,
            enabled: false,
          ),
          const SizedBox(height: 16),
          EbiTextField(
            controller: _phoneController,
            labelText: 'Phone',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          EbiTextField(
            controller: _companyController,
            labelText: 'Company',
            prefixIcon: Icons.business_outlined,
          ),
          const SizedBox(height: 32),
          EbiButton(
            text: 'Save Changes',
            width: double.infinity,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
