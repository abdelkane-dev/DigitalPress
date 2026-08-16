import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../config/api_constants.dart';

/// Feuille de demande de retrait — utilisée côté Éditeur ET côté Admin.
///
/// ─── MÊME STYLE QUE LE PAIEMENT LECTEUR (demande explicite) ────────────
/// Les rangées de moyens de paiement/retrait reprennent exactement la
/// présentation du PaymentSelectionSheet des lecteurs : icône colorée dans
/// un rond, titre, sous-titre et chevron.
///
/// ─── CONFIRMATION OTP (protection des retraits frauduleux) ─────────────
/// Étape 1 : choix SÉLECTIF du moyen (Wave, Orange Money, Moov Money,
/// carte bancaire, virement).
/// Étape 2 : saisie du numéro/compte puis du montant à recevoir.
/// Étape 3 : choix du canal de réception du code (email ou SMS) — le code
///           est envoyé par le backend (POST /paiements/retrait/otp/).
/// Étape 4 : saisie du code à 6 chiffres reçu ; c'est seulement après ce
///           code que la demande de retrait est créée côté serveur.
///
/// Renvoie {'mode', 'numero', 'montant', 'otp_code'} via Navigator.pop, ou
/// null si annulé. Les erreurs serveur (code invalide, solde insuffisant…)
/// sont affichées dans la feuille avec le message exact du backend.
Future<Map<String, String>?> showWithdrawalRequestSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _WithdrawalRequestSheet(),
  );
}

class _MethodInfo {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String hint;

  const _MethodInfo({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.hint,
  });
}

const List<_MethodInfo> _modes = [
  _MethodInfo(
    value: 'wave',
    label: 'Wave',
    subtitle: 'Rapide et sécurisé',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF49B8E7),
    hint: 'Numéro Wave (ex: +223 70 00 00 00)',
  ),
  _MethodInfo(
    value: 'orange_money',
    label: 'Orange Money',
    subtitle: 'Simple et sécurisé',
    icon: Icons.payments_rounded,
    color: Color(0xFFFF7900),
    hint: 'Numéro Orange Money',
  ),
  _MethodInfo(
    value: 'moov_money',
    label: 'Moov Money',
    subtitle: 'Paiement mobile Moov',
    icon: Icons.phone_android_rounded,
    color: Color(0xFF003399),
    hint: 'Numéro Moov Money',
  ),
  _MethodInfo(
    value: 'card',
    label: 'Carte Bancaire',
    subtitle: 'Visa, Mastercard — CinetPay',
    icon: Icons.credit_card_rounded,
    color: Color(0xFF635BFF),
    hint: 'Numéro de carte',
  ),
  _MethodInfo(
    value: 'bank',
    label: 'Virement bancaire',
    subtitle: 'Vers un compte bancaire',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF10B981),
    hint: 'IBAN / RIB',
  ),
];

class _WithdrawalRequestSheet extends ConsumerStatefulWidget {
  const _WithdrawalRequestSheet();

  @override
  ConsumerState<_WithdrawalRequestSheet> createState() =>
      _WithdrawalRequestSheetState();
}

class _WithdrawalRequestSheetState extends ConsumerState<_WithdrawalRequestSheet> {
  static const _accent = Color(0xFFEA580C);

  final _numeroController = TextEditingController();
  final _montantController = TextEditingController();
  final _otpController = TextEditingController();

  /// null = étape 1 (choix du moyen), sinon le moyen sélectionné.
  _MethodInfo? _selected;
  bool _submitting = false;

  /// true dès que le numéro/montant sont saisis : on passe à la saisie OTP.
  bool _otpStep = false;

  /// Canal de réception choisi : 'email' ou 'sms'.
  String _channel = 'email';

  /// Destinataire masqué renvoyé par le backend (ex: j***@gmail.com).
  String _destination = '';

  /// Message d'erreur du backend (ex: code invalide, solde insuffisant).
  String? _error;

  int _resendTimer = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _numeroController.dispose();
    _montantController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _resendTimer--;
        if (_resendTimer <= 0) timer.cancel();
      });
    });
  }

  /// Envoie le code OTP (étape 3) : POST /paiements/retrait/otp/.
  Future<void> _requestOtp() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        ApiConstants.withdrawalOtp,
        data: {'channel': _channel},
      );
      final data = res.data is Map ? res.data as Map : {};
      if (mounted) {
        setState(() {
          _otpStep = true;
          _destination = data['destination']?.toString() ?? '';
          _otpController.clear();
        });
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '').trim();
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Renvoie le code (étape 4, bouton « Renvoyer »).
  Future<void> _resendOtp() async {
    setState(() => _error = null);
    await _requestOtp();
  }

  /// Valide la demande avec le code saisi puis referme la feuille en
  /// renvoyant tout au caller, qui crée la demande côté serveur.
  Future<void> _submit() async {
    final montant = double.tryParse(_montantController.text.trim());
    if (montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez saisir un montant valide.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (_numeroController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez saisir un numéro/compte valide.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _error = 'Veuillez saisir le code à 6 chiffres reçu.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    Navigator.pop(context, {
      'mode': _selected!.value,
      'numero': _numeroController.text.trim(),
      'montant': _montantController.text.trim(),
      'otp_code': otp,
    });
  }

  void _goBack() {
    setState(() {
      if (_otpStep) {
        _otpStep = false;
        _error = null;
      } else {
        _selected = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_selected != null)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: Colors.grey.shade600),
                    onPressed: _goBack,
                  ),
                Expanded(
                  child: Text(
                    _otpStep
                        ? 'Confirmation'
                        : (_selected == null
                            ? 'Retirer des fonds'
                            : _selected!.label),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _otpStep
                  ? 'Saisissez le code reçu pour confirmer le retrait'
                  : (_selected == null
                      ? 'Choisissez votre moyen de retrait'
                      : 'Indiquez le numéro/compte puis le montant à recevoir'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            if (_selected == null)
              _buildMethodList()
            else if (!_otpStep)
              _buildDetailsForm()
            else
              _buildOtpForm(),
          ],
        ),
      ),
    );
  }

  // ─── ÉTAPE 1 : choix du moyen (style lecteur) ──────────────────────────
  Widget _buildMethodList() {
    return Column(
      children: _modes.map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => setState(() => _selected = m),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.color.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(m.icon, color: m.color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          m.subtitle,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey.shade300),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── ÉTAPE 2 : numéro + montant ────────────────────────────────────────
  Widget _buildDetailsForm() {
    final m = _selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _numeroController,
          decoration: InputDecoration(
            labelText: m.hint,
            prefixIcon: Icon(m.icon, color: m.color),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: m.color, width: 1.6)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _montantController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Montant à recevoir (FCFA)',
            prefixIcon:
                const Icon(Icons.attach_money_rounded, color: _accent),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _accent, width: 1.6)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
        const SizedBox(height: 16),
        // ─── CANAL DE RÉCEPTION DU CODE (email / SMS) ────────────────────
        Text(
          'Recevoir le code de confirmation par :',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _channelChip('email', Icons.email_rounded, 'Email'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _channelChip('sms', Icons.sms_rounded, 'SMS'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _submitting ? null : _requestOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.4))
                : const Text('Envoyer le code de confirmation',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _channelChip(String value, IconData icon, String label) {
    final selected = _channel == value;
    return InkWell(
      onTap: () => setState(() => _channel = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEA580C).withAlpha(18) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFEA580C) : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? const Color(0xFFEA580C) : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFFEA580C) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ÉTAPE 3 : saisie du code OTP ──────────────────────────────────────
  Widget _buildOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_destination.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withAlpha(10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEA580C).withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: Color(0xFFEA580C), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Code envoyé à $_destination (valable 15 min).',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 12,
            color: Color(0xFF0D47A1),
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: TextStyle(
                fontSize: 22, color: Colors.grey.shade300, letterSpacing: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.6)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.4))
                : const Text('Valider la demande de retrait',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: _resendTimer > 0
              ? Text(
                  'Renvoyer le code dans ${_resendTimer}s',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500),
                )
              : TextButton.icon(
                  onPressed: _submitting ? null : _resendOtp,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Renvoyer le code'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                  ),
                ),
        ),
      ],
    );
  }
}
