import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/services/auth_service.dart';

/// Écran de connexion / inscription pour la stack Riverpod + GoRouter.
class AuthLoginScreen extends ConsumerStatefulWidget {
  final bool initialRegisterMode;

  const AuthLoginScreen({super.key, this.initialRegisterMode = false});

  @override
  ConsumerState<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends ConsumerState<AuthLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  late bool _isRegister;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool? _backendOnline;
  String? _serverMessage;
  bool _backendStatusVisible = true;
  Timer? _backendStatusTimer;
  // Point 1 : consentement explicite aux CGU en mode inscription
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.initialRegisterMode;
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    if (mounted) {
      setState(() {
        _backendOnline = null;
        _serverMessage = null;
        _backendStatusVisible = true;
      });
    }
    final health = await ref.read(apiClientProvider).healthCheck();
    if (mounted) {
      setState(() {
        _backendOnline = health.isOnline;
        _serverMessage = health.serverMessage;
        _backendStatusVisible = true;
      });
    }
    if (health.isOnline) {
      _startBackendStatusHideTimer();
    }
  }

  void _startBackendStatusHideTimer() {
    _backendStatusTimer?.cancel();
    _backendStatusTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _backendStatusVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _backendStatusTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Point 1 : bloquer l'inscription si les CGU ne sont pas acceptées
    if (_isRegister && !_acceptedTerms) {
      _showError('Veuillez accepter les Conditions Générales d\'Utilisation pour vous inscrire.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      if (_isRegister) {
        await auth.signUpWithEmailAndPassword(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        );
      } else {
        await auth.signInWithEmailAndPassword(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      }
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE63946),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A2647),
              Color(0xFF144272),
              Color(0xFF205295),
              Color(0xFF2C74B3),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isRegister ? 'Créer un compte' : 'Connexion',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_isRegister) ...[
                        _field(
                          controller: _nameCtrl,
                          label: 'Nom',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _field(
                        controller: _emailCtrl,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email requis';
                          final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
                          if (!emailRegex.hasMatch(v.trim())) return 'Email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _field(
                        controller: _passwordCtrl,
                        label: 'Mot de passe',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Mot de passe requis';
                          }
                          if (v.length < 6) {
                            return 'Minimum 6 caractères';
                          }
                          return null;
                        },
                      ),
                      // Point 1 : confirmation de mot de passe + CGU en mode inscription
                      if (_isRegister) ...[
                        const SizedBox(height: 16),
                        _field(
                          controller: _passwordConfirmCtrl,
                          label: 'Confirmer le mot de passe',
                          icon: Icons.lock_reset_outlined,
                          obscure: _obscureConfirm,
                          suffix: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Confirmez votre mot de passe';
                            if (v != _passwordCtrl.text) return 'Les mots de passe ne correspondent pas';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Checkbox CGU obligatoire
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                              activeColor: Colors.white,
                              checkColor: const Color(0xFF0A2647),
                              side: const BorderSide(color: Colors.white70),
                            ),
                            Expanded(
                              child: Text(
                                'J\'accepte les Conditions Générales d\'Utilisation et la Politique de confidentialité',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0A2647),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isRegister ? "S'inscrire" : 'Se connecter',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      if (!_isRegister) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              context.push('/auth/forgot-password'),
                          child: const Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isRegister = !_isRegister),
                        child: Text(
                          _isRegister
                              ? 'Déjà un compte ? Se connecter'
                              : 'Pas de compte ? S\'inscrire',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _backendStatusBanner(),
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

  Widget _backendStatusBanner() {
    if (!_backendStatusVisible) {
      return const SizedBox.shrink();
    }
    if (_backendOnline == null) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white54,
        ),
      );
    }
    final online = _backendOnline!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: online
            ? const Color.fromRGBO(6, 214, 160, 0.2)
            : const Color.fromRGBO(230, 57, 70, 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: online ? const Color(0xFF06D6A0) : const Color(0xFFE63946),
        ),
      ),
      child: Row(
        children: [
          Icon(
            online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              buildHealthStatusMessage(
                isOnline: online,
                serverMessage: _serverMessage,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          if (!online)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              onPressed: _checkBackend,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2C74B3)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
