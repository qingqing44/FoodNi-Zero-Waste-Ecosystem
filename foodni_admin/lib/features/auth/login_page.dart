import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../dashboard/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  final error = await _authService.loginAdmin(
    _emailController.text.trim(),
    _passwordController.text.trim(),
  );

  if (mounted) {
    setState(() => _isLoading = false);

    if (error == null) {
      // SUCCESS: Manually go to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    } else {
      // FAILURE: Show the alert dialog
      _showErrorDialog(context, error);
    }
  }
}

void _showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Access Denied', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK', style: TextStyle(color: Color(0xFF052A1E))),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FoodNi Admin',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF052A1E)),
              ),
              const SizedBox(height: 8),
              const Text('Sign in to access the dashboard', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: 'Admin Email', prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}