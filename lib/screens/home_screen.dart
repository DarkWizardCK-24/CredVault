import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:password_manager/models/password.dart';
import 'package:password_manager/screens/login_page.dart';
import 'package:password_manager/screens/profile_page.dart';
import 'package:password_manager/services/firestore_service.dart';
import 'package:password_manager/widgets/password_card.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  late Animation<double> _titleAnimation;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );
    _titleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _showAddPasswordDialog({PasswordModel? password}) {
    final usernameController = TextEditingController(text: password?.username);
    final passwordController = TextEditingController(text: password?.password);
    final linkController = TextEditingController(text: password?.link);
    String? selectedSocialMedia = password?.socialMedia ?? 'GitHub';
    final socialMediaOptions = [
      'GitHub',
      'Linktree',
      'Google',
      'Mail',
      'Instagram',
      'LinkedIn',
      'YouTube',
      'Portfolio',
      'Others',
    ];
    final socialMediaIcons = {
      'GitHub': Icons.code,
      'Linktree': Icons.link,
      'Google': Icons.g_mobiledata,
      'Mail': Icons.email,
      'Instagram': Icons.camera_alt,
      'LinkedIn': Icons.business,
      'YouTube': Icons.videocam,
      'Portfolio': Icons.work,
      'Others': Icons.lock,
    };
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.8),
                Colors.cyan.withOpacity(0.8),
                Colors.green.withOpacity(0.8),
                Colors.greenAccent.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          password == null
                              ? 'Add Credential'
                              : 'Edit Credential',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4)
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        buildDialogTextField(
                            usernameController, 'Username', Icons.person),
                        const SizedBox(height: 12),
                        buildDialogTextField(
                            passwordController, 'Password', Icons.lock,
                            isPassword: true),
                        const SizedBox(height: 12),
                        buildDialogTextField(
                            linkController, 'Link (optional)', Icons.link,
                            isOptional: true),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedSocialMedia,
                          decoration: InputDecoration(
                            labelText: 'Platform',
                            prefixIcon:
                                const Icon(Icons.share, color: Colors.white),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.25),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            labelStyle: GoogleFonts.inter(
                              fontWeight: FontWeight.w400,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          dropdownColor: Colors.white.withOpacity(0.95),
                          items: socialMediaOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  Icon(socialMediaIcons[value],
                                      color: Colors.cyan),
                                  const SizedBox(width: 10),
                                  Text(
                                    value,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            selectedSocialMedia = newValue;
                          },
                          validator: (value) =>
                              value == null ? 'Please select a platform' : null,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user == null) {
                                    Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const LoginPage()));
                                    return;
                                  }
                                  final passwordModel = PasswordModel(
                                    id: password?.id ?? const Uuid().v4(),
                                    userId: user.uid,
                                    username: usernameController.text,
                                    password: passwordController.text,
                                    socialMedia: selectedSocialMedia!,
                                    link: linkController.text,
                                    createdAt:
                                        password?.createdAt ?? DateTime.now(),
                                    updatedAt: DateTime.now(),
                                  );
                                  try {
                                    if (password == null) {
                                      await _firestoreService
                                          .addPassword(passwordModel);
                                    } else {
                                      await _firestoreService
                                          .updatePassword(passwordModel);
                                    }
                                    Navigator.pop(context);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.withOpacity(0.9),
                                      Colors.cyan.withOpacity(0.9),
                                      Colors.green.withOpacity(0.9),
                                      Colors.greenAccent.withOpacity(0.9),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                child: Text(
                                  password == null ? 'Save' : 'Update',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildDialogTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isPassword = false, bool isOptional = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.white, size: 22),
          filled: true,
          fillColor: Colors.white.withOpacity(0.25),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 15,
            color: Colors.white,
          ),
          hintStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 15,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          fontSize: 15,
          color: Colors.white,
        ),
        validator: isOptional
            ? null
            : (value) => value!.isEmpty ? 'Enter $label' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginPage();
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.9),
                    Colors.cyan.withOpacity(0.9),
                    Colors.green.withOpacity(0.9),
                    Colors.greenAccent.withOpacity(0.9),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            title: Text(
              '🔑CredVault',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                shadows: [
                  Shadow(
                    blurRadius: 16.0,
                    color: Colors.black.withOpacity(0.2),
                    offset: const Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.person, color: Colors.black, size: 30),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage(),),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<PasswordModel>>(
                    stream: _firestoreService.getPasswords(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Something went wrong',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w400,
                              fontSize: 18,
                              color: Colors.black.withOpacity(0.9),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.black));
                      }
                      final passwords = snapshot.data!;
                      if (passwords.isEmpty) {
                        return Center(
                          child: Text(
                            'No credentials yet. Add one!',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Colors.black.withOpacity(0.9),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: passwords.length,
                        itemBuilder: (context, index) {
                          final password = passwords[index];
                          return PasswordCard(
                            password: password,
                            index: index,
                            onEdit: () =>
                                _showAddPasswordDialog(password: password),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: ScaleTransition(
            scale: _fabAnimation,
            child: FloatingActionButton(
              onPressed: () => _showAddPasswordDialog(),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.9),
                      Colors.cyan.withOpacity(0.9),
                      Colors.green.withOpacity(0.9),
                      Colors.greenAccent.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
