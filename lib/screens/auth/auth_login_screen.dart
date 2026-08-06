import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isLoading = false;
  bool? _backendOnline;
  String? _serverMessage;
  bool _backendStatusVisible = true;
  Timer? _backendStatusTimer;

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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Image de fond spécifique à cette page
          Positioned.fill(
            child: Image.asset(
              'assets/auth_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
          // Voile sombre pour lisibilité
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/app_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Textes avec hiérarchie claire
                        Text(
                          'Digital Press',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w600, // SemiBold
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'votre kiosque numérique',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFE5E7EB), // Gris clair pour le contraste
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32), // Interface plus aérée
                        
                        // Titre d'action
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            _isRegister ? "S'inscrire" : 'Connexion',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        if (_isRegister) ...[
                          _field(
                            controller: _nameCtrl,
                            label: 'Nom complet',
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
                            if (v == null || v.isEmpty) return 'L\'adresse e-mail est requise';
                            if (!v.contains('@')) return 'L\'adresse e-mail n\'est pas valide';
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
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFFE5E7EB),
                              size: 22,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Le mot de passe est requis';
                            }
                            if (v.length < 6) {
                              return 'Au moins 6 caractères';
                            }
                            return null;
                          },
                        ),
                        if (_isRegister) ...[
                          const SizedBox(height: 16),
                          _field(
                            controller: _passwordConfirmCtrl,
                            label: 'Confirmer le mot de passe',
                            icon: Icons.lock_outline,
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFFE5E7EB),
                                size: 22,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'La confirmation est requise';
                              }
                              if (v != _passwordCtrl.text) {
                                return 'Les mots de passe ne correspondent pas';
                              }
                              return null;
                            },
                          ),
                        ],
                        
                        if (!_isRegister) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  context.push('/auth/forgot-password'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFE5E7EB),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Mot de passe oublié ?',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Bouton principal modernisé
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF336B82), // Teal/slate blue solide correspondant à l'image
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isRegister ? "S'inscrire" : 'Se connecter',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                        
                        if (_isRegister) ...[
                          const SizedBox(height: 24),
                          
                          // Séparateur
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'ou inscrivez-vous avec',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFE5E7EB),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Boutons sociaux
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialButton('Google', _isRegister),
                              const SizedBox(width: 32),
                              _buildSocialButton('Facebook', _isRegister),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                        ] else ...[
                          const SizedBox(height: 32),
                        ],
                        
                        // Lien vers l'autre mode
                        TextButton(
                          onPressed: () =>
                              setState(() => _isRegister = !_isRegister),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(color: const Color(0xFFE5E7EB), fontSize: 15),
                              children: [
                                TextSpan(
                                  text: _isRegister ? 'Déjà inscrit ? ' : 'Pas encore inscrit ? ',
                                ),
                                TextSpan(
                                  text: _isRegister ? 'Connectez-vous' : "S'inscrire",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white, // Blanc gras comme dans l'image
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _backendStatusBanner(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(String type, bool isRegister) {
    final isGoogle = type == 'Google';
    return Column(
      children: [
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // ignore: deprecated_member_use
              color: Colors.white.withValues(alpha: 0.12), // Fond blanc semi-transparent
              // ignore: deprecated_member_use
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
            ),
            child: Center(
              child: isGoogle
                  ? Image.network(
                      'https://img.icons8.com/color/48/000000/google-logo.png',
                      width: 28,
                      height: 28,
                      errorBuilder: (context, error, stackTrace) => const Text(
                        'G',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 32),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isRegister ? 'S\'inscrire avec\n$type' : 'Connexion avec\n$type',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: const Color(0xFFE5E7EB),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: online
            ? const Color.fromRGBO(6, 214, 160, 0.15)
            : const Color.fromRGBO(230, 57, 70, 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: online ? const Color(0xFF06D6A0) : const Color(0xFFE63946),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              buildHealthStatusMessage(
                isOnline: online,
                serverMessage: _serverMessage,
              ),
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
            ),
          ),
          if (!online)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
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
      style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: label,
        // ignore: deprecated_member_use
        hintStyle: GoogleFonts.poppins(color: const Color(0xFFE5E7EB).withValues(alpha: 0.8), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFFE5E7EB), size: 22),
        suffixIcon: suffix,
        filled: true,
        // ignore: deprecated_member_use
        fillColor: Colors.black.withValues(alpha: 0.15), // Fond très légèrement sombre/transparent
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          // ignore: deprecated_member_use
          borderSide: BorderSide(color: const Color(0xFF56B4E9).withValues(alpha: 0.6), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          // ignore: deprecated_member_use
          borderSide: BorderSide(color: const Color(0xFF56B4E9).withValues(alpha: 0.6), width: 1.5), // Ligne bleue lumineuse constante
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF56B4E9), width: 2.0), // Bleu plus vif au focus
        ),
        errorStyle: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontWeight: FontWeight.w500, fontSize: 12),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      ),
    );
  }
}

