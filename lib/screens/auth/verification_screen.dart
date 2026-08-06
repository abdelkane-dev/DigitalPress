import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String? phoneNumber;
  final String mode;

  const VerificationScreen({
    super.key,
    required this.email,
    this.phoneNumber,
    this.mode = 'reset',
  });

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verify() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      _showSnackBar('Veuillez entrer le code complet', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).verifyCode(widget.email, code);

      if (mounted) {
        _showSnackBar('Code vérifié avec succès !', isError: false);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          context.pushReplacement(
            '/auth/reset-password'
            '?email=${Uri.encodeComponent(widget.email)}'
            '&code=${Uri.encodeComponent(code)}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Code invalide: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resendTimer > 0) return;

    setState(() {
      _resendTimer = 60;
      _isLoading = true;
    });

    try {
      await ref.read(authServiceProvider).resendVerificationCode(widget.email);

      if (mounted) {
        _showSnackBar('Code renvoyé avec succès', isError: false);
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE63946)
            : const Color(0xFF06D6A0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildCodeInputCard(),
                      const SizedBox(height: 32),
                      _buildVerifyButton(),
                      const SizedBox(height: 24),
                      _buildResendButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            // ignore: deprecated_member_use
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.verified_user_rounded,
            size: 56,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Vérification',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Entrez le code envoyé à',
          style: TextStyle(
            fontSize: 16,
            // ignore: deprecated_member_use
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.email,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeInputCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          return SizedBox(
            width: 45,
            height: 56,
            child: TextFormField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0A2647),
              ),
              cursorColor: const Color(0xFF2C74B3),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2C74B3),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty && index < 5) {
                  _focusNodes[index + 1].requestFocus();
                } else if (value.isEmpty && index > 0) {
                  _focusNodes[index - 1].requestFocus();
                }

                if (index == 5 && value.isNotEmpty) {
                  final code = _controllers.map((c) => c.text).join();
                  if (code.length == 6) {
                    _verify();
                  }
                }
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2647), Color(0xFF2C74B3)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: const Color(0xFF2C74B3).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verify,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Vérifier',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildResendButton() {
    return Column(
      children: [
        if (_resendTimer > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  'Renvoyer le code dans ${_resendTimer}s',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          TextButton(
            onPressed: _resendCode,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Renvoyer le code',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
