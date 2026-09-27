import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'role_dashboard_screen.dart';

const adminEmail = 'mauryasujeet698@gmail.com';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const AllwaysAdminApp());
}

class AllwaysAdminApp extends StatelessWidget {
  const AllwaysAdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ALLways Admin',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC2185B)),
      scaffoldBackgroundColor: const Color(0xFFF8F8F8),
    ),
    home: const AdminAuthGate(),
  );
}

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});
  Future<bool> _isAdmin(User user) async {
    if ((user.email ?? '').trim().toLowerCase() == adminEmail.toLowerCase()) return true;
    final snap = await FirebaseFirestore.instance.collection('customers').doc(user.uid).get();
    return (snap.data()?['role'] ?? '').toString().toLowerCase() == 'admin';
  }
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snap) {
      final user = snap.data;
      if (user == null) return const AdminLoginPage();
      return FutureBuilder<bool>(
        future: _isAdmin(user),
        builder: (context, access) {
          if (!access.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (access.data != true) {
            FirebaseAuth.instance.signOut();
            return const AdminLoginPage(message: 'This account does not have Admin access.');
          }
          return RoleDashboardScreen(
            role: 'admin',
            user: user,
            child: const SizedBox.shrink(),
            onSignOut: () => FirebaseAuth.instance.signOut(),
          );
        },
      );
    },
  );
}

class AdminLoginPage extends StatefulWidget {
  final String? message;
  const AdminLoginPage({super.key, this.message});
  @override State<AdminLoginPage> createState() => _AdminLoginPageState();
}
class _AdminLoginPageState extends State<AdminLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false, obscure = true;
  String? error;

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? e.code);
    } catch (e) {
      setState(() => error = e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> signInWithGoogle() async {
    setState(() { busy = true; error = null; });
    try {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception('Google Sign-In is not supported on this device.');
      }
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google Sign-In did not return an ID token.');
      }
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } on GoogleSignInException catch (e) {
      if (mounted) setState(() => error = e.description ?? e.code.toString());
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0x1FC2185B),
                      child: Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFC2185B), size: 32),
                    ),
                    const SizedBox(height: 18),
                    const Text('ALLways Admin', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    const Text('Platform operations, orders and controls.'),
                    if (widget.message != null) ...[
                      const SizedBox(height: 10),
                      Text(widget.message!, style: const TextStyle(color: Colors.red)),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 20),
                    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Admin email')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: busy ? null : submit,
                        child: busy ? const CircularProgressIndicator() : const Text('Sign in'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(children: [
                        Expanded(child: Divider()),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR')),
                        Expanded(child: Divider()),
                      ]),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : signInWithGoogle,
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('Sign in with Google'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
