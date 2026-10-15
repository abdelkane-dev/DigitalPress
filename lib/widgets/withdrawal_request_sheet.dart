import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../config/api_constants.dart';

/// Feuille de demande de retrait — style identique au PaymentScreen lecteur.
///
/// Les champs s'adaptent au mode de retrait choisi :
///   • Mobile Money (Wave/OM/Moov) → numéro de téléphone + indicatif pays
///   • Carte Bancaire (Visa/MC) → numéro de carte, expiry, CVV, titulaire
///   • Virement bancaire → IBAN / RIB
///
/// Étape 1 : choix du moyen → même style que PaymentSelectionSheet.
/// Étape 2 : formulaire détails avec EN-TÊTE GRADIENT identique au
///           PaymentScreen.
/// Étape 3 : saisie OTP (code à 6 chiffres).
///
/// Renvoie {'mode', 'numero', 'montant', 'otp_code'} ou null si annulé.
Future<Map<String, String>?> showWithdrawalRequestSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _WithdrawalRequestSheet(),
  );
}

// ─── FORMATTERS ───────────────────────────────────────────────────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    if (digits.length > 16) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length > 4) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

// ─── PAYS ─────────────────────────────────────────────────────────────────────
class _CountryInfo {
  final String name;
  final String flag;
  final String dialCode;
  final int minDigits;
  final int maxDigits;
  const _CountryInfo(
      {required this.name,
      required this.flag,
      required this.dialCode,
      required this.minDigits,
      required this.maxDigits});
  String get display => '$flag  $name ($dialCode)';
}

const List<_CountryInfo> _kCountries = [
  _CountryInfo(name: 'Mali', flag: '🇲🇱', dialCode: '+223', minDigits: 8, maxDigits: 8),
  _CountryInfo(name: 'Sénégal', flag: '🇸🇳', dialCode: '+221', minDigits: 9, maxDigits: 9),
  _CountryInfo(name: "Côte d'Ivoire", flag: '🇨🇮', dialCode: '+225', minDigits: 10, maxDigits: 10),
  _CountryInfo(name: 'Burkina Faso', flag: '🇧🇫', dialCode: '+226', minDigits: 8, maxDigits: 8),
  _CountryInfo(name: 'Niger', flag: '🇳🇪', dialCode: '+227', minDigits: 8, maxDigits: 8),
  _CountryInfo(name: 'Guinée', flag: '🇬🇳', dialCode: '+224', minDigits: 9, maxDigits: 9),
  _CountryInfo(name: 'Cameroun', flag: '🇨🇲', dialCode: '+237', minDigits: 9, maxDigits: 9),
  _CountryInfo(name: 'France', flag: '🇫🇷', dialCode: '+33', minDigits: 9, maxDigits: 9),
];

// ─── INFOS MOYENS ─────────────────────────────────────────────────────────────
class _MethodInfo {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String hint;
  const _MethodInfo(
      {required this.value,
      required this.label,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.hint});
}

const List<_MethodInfo> _modes = [
  _MethodInfo(value: 'wave', label: 'Wave', subtitle: 'Rapide et sécurisé', icon: Icons.water_drop_rounded, color: Color(0xFF49B8E7), hint: 'Numéro Wave (ex: +223 70 00 00 00)'),
  _MethodInfo(value: 'orange_money', label: 'Orange Money', subtitle: 'Simple et sécurisé', icon: Icons.payments_rounded, color: Color(0xFFFF7900), hint: 'Numéro Orange Money'),
  _MethodInfo(value: 'moov_money', label: 'Moov Money', subtitle: 'Paiement mobile Moov', icon: Icons.phone_android_rounded, color: Color(0xFF003399), hint: 'Numéro Moov Money'),
  _MethodInfo(value: 'card', label: 'Carte Bancaire', subtitle: 'Visa, Mastercard — CinetPay', icon: Icons.credit_card_rounded, color: Color(0xFF635BFF), hint: 'Numéro de carte'),
  _MethodInfo(value: 'bank', label: 'Virement bancaire', subtitle: 'Vers un compte bancaire', icon: Icons.account_balance_rounded, color: Color(0xFF10B981), hint: 'IBAN / RIB'),
];

class _WithdrawalRequestSheet extends ConsumerStatefulWidget {
  const _WithdrawalRequestSheet();
  @override
  ConsumerState<_WithdrawalRequestSheet> createState() => _WithdrawalRequestSheetState();
}

class _WithdrawalRequestSheetState extends ConsumerState<_WithdrawalRequestSheet> {
  static const _navy = Color(0xFF0A2647);
  static const _accent = Color(0xFFEA580C);

  // ── Controllers ──────────────────────────────────────────────────────────
  final _numeroController = TextEditingController();
  final _montantController = TextEditingController();
  final _otpController = TextEditingController();
  // Carte bancaire
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  _MethodInfo? _selected;
  bool _submitting = false;
  bool _otpStep = false;
  String _channel = 'email';
  String _destination = '';
  String? _error;
  int _resendTimer = 0;
  Timer? _timer;
  _CountryInfo _selectedCountry = _kCountries.first;
  String? _cardType;

  bool get _isMobileMoney =>
      _selected?.value == 'wave' ||
      _selected?.value == 'orange_money' ||
      _selected?.value == 'moov_money';
  bool get _isCard => _selected?.value == 'card';
  bool get _isBank => _selected?.value == 'bank';

  String? _detectCardType(String raw) {
    final d = raw.replaceAll(' ', '');
    if (d.isEmpty) return null;
    if (d.startsWith('34') || d.startsWith('37')) return 'amex';
    if (d.length >= 2) {
      final t = int.tryParse(d.substring(0, 2)) ?? 0;
      if (t >= 51 && t <= 55) return 'mastercard';
    }
    if (d.length >= 4) {
      final f = int.tryParse(d.substring(0, 4)) ?? 0;
      if (f >= 2221 && f <= 2720) return 'mastercard';
    }
    if (d.startsWith('4')) return 'visa';
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _numeroController.dispose();
    _montantController.dispose();
    _otpController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _resendTimer--;
        if (_resendTimer <= 0) t.cancel();
      });
    });
  }

  Future<void> _requestOtp() async {
    // Validation selon le mode
    if (_isMobileMoney && _numeroController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un numéro valide.'), backgroundColor: Colors.red));
      return;
    }
    if (_isCard) {
      final raw = _numeroController.text.replaceAll(' ', '');
      if (raw.length < 13) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro de carte invalide.'), backgroundColor: Colors.red));
        return;
      }
      if (_expiryController.text.length < 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Date d\'expiration invalide (MM/AA).'), backgroundColor: Colors.red));
        return;
      }
      if (_cvvController.text.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CVV invalide.'), backgroundColor: Colors.red));
        return;
      }
      if (_cardHolderController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nom du titulaire requis.'), backgroundColor: Colors.red));
        return;
      }
    }
    if (_isBank && _numeroController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un IBAN/RIB valide.'), backgroundColor: Colors.red));
      return;
    }
    final montant = double.tryParse(_montantController.text.trim());
    if (montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant invalide.'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(ApiConstants.withdrawalOtp, data: {'channel': _channel});
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
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', '').trim(); });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() { _error = 'Veuillez saisir le code à 6 chiffres reçu.'; });
      return;
    }
    // Construire le numéro complet
    String numero;
    if (_isCard) {
      numero = '${_numeroController.text.replaceAll(' ', '')}|${_expiryController.text}|${_cvvController.text}|${_cardHolderController.text.trim()}';
    } else if (_isMobileMoney) {
      numero = '${_selectedCountry.dialCode} ${_numeroController.text.trim()}';
    } else {
      numero = _numeroController.text.trim();
    }
    setState(() { _submitting = true; _error = null; });
    Navigator.pop(context, {
      'mode': _selected!.value,
      'numero': numero,
      'montant': _montantController.text.trim(),
      'otp_code': otp,
    });
  }

  void _goBack() {
    setState(() {
      if (_otpStep) { _otpStep = false; _error = null; }
      else { _selected = null; _cardType = null; }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          if (_selected == null)
            Expanded(child: _buildMethodListStep())
          else if (!_otpStep)
            Expanded(child: SingleChildScrollView(child: Column(children: [_buildGradientHeader(), _buildSummary(), _buildFormSection()])))
          else
            Expanded(child: SingleChildScrollView(child: Column(children: [_buildGradientHeader(), _buildSummary(), _buildOtpSection()]))),
        ],
      ),
    );
  }

  // ═══ ÉTAPE 1 : CHOIX DU MOYEN ═════════════════════════════════════════════
  Widget _buildMethodListStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Retirer des fonds', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _navy)),
                const SizedBox(height: 4),
                Text('Choisissez votre moyen de retrait', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            )),
            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: Colors.grey.shade400)),
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _modes.length,
          itemBuilder: (ctx, i) {
            final m = _modes[i];
            return Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(
              onTap: () => setState(() => _selected = m),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: m.color.withAlpha(25), shape: BoxShape.circle), child: Icon(m.icon, color: m.color)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(m.subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
                ]),
              ),
            ));
          },
        )),
      ],
    );
  }

  // ═══ HEADER GRADIENT ══════════════════════════════════════════════════════
  Widget _buildGradientHeader() {
    final m = _selected!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, m.color.withAlpha(180)])),
      child: Column(children: [
        Row(children: [
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22), onPressed: _goBack),
          const Spacer(),
          IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: Colors.white.withAlpha(180), size: 22)),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle), child: Icon(m.icon, color: Colors.white, size: 40)),
        const SizedBox(height: 12),
        Text(_otpStep ? 'Confirmation' : m.label, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: m.color, borderRadius: BorderRadius.circular(20)),
          child: const Text('Retrait', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  // ═══ RÉCAPITULATIF ═══════════════════════════════════════════════════════
  Widget _buildSummary() {
    final m = _selected!;
    final montant = _montantController.text.isNotEmpty ? _montantController.text : '—';
    String numero = '—';
    if (_isCard) {
      final raw = _numeroController.text.replaceAll(' ', '');
      if (raw.isNotEmpty) {
        final masked = raw.length > 8 ? '${raw.substring(0, 4)} **** **** ${raw.substring(raw.length - 4)}' : raw;
        numero = '$masked  •  ${_expiryController.text.isNotEmpty ? _expiryController.text : 'MM/AA'}';
      }
    } else if (_numeroController.text.isNotEmpty) {
      numero = _isMobileMoney ? '${_selectedCountry.dialCode} ${_numeroController.text}' : _numeroController.text;
    }
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _navy.withAlpha(8), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: m.color.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.receipt_long_rounded, color: m.color, size: 20)),
          const SizedBox(width: 12),
          const Text('Récapitulatif', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)),
        ]),
        const SizedBox(height: 16),
        _summaryRow('Moyen de retrait', m.label),
        const Divider(height: 24),
        _summaryRow(_isCard ? 'Carte' : _isBank ? 'IBAN/RIB' : 'Numéro', numero),
        const Divider(height: 24),
        _summaryRow('Canal de code', _channel == 'email' ? 'Email' : 'SMS'),
        const Divider(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Montant à recevoir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)),
          Text('$montant FCFA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: m.color)),
        ]),
      ]),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      Flexible(child: Text(value, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy))),
    ]);
  }

  // ═══ FORMULAIRE ADAPTATIF ═══════════════════════════════════════════════
  Widget _buildFormSection() {
    final m = _selected!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _navy.withAlpha(8), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Titre
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: m.color.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(m.icon, color: m.color, size: 20)),
          const SizedBox(width: 12),
          const Text('Informations de retrait', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)),
        ]),
        const SizedBox(height: 20),

        // Champs adaptatifs
        if (_isMobileMoney) _buildMobileMoneyFields(m),
        if (_isCard) _buildCardFields(m),
        if (_isBank) _buildBankFields(m),

        const SizedBox(height: 16),

        // Montant (toujours présent)
        const Text('Montant à recevoir', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(height: 8),
        TextField(
          controller: _montantController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(hint: 'Ex: 50000', prefixIcon: const Icon(Icons.attach_money_rounded, color: _accent), suffix: const Text('FCFA', style: TextStyle(fontWeight: FontWeight.w800, color: _accent))),
        ),
        const SizedBox(height: 20),

        // Canal de réception
        const Text('Recevoir le code de confirmation par', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _channelChip('email', Icons.email_rounded, 'Email', m.color)),
          const SizedBox(width: 10),
          Expanded(child: _channelChip('sms', Icons.sms_rounded, 'SMS', m.color)),
        ]),
        const SizedBox(height: 16),
        _buildInfoBanner('Un code de confirmation sera envoyé pour sécuriser votre retrait.', m.color),
        const SizedBox(height: 20),

        // Bouton envoyer
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _submitting ? null : _requestOtp,
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _submitting ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Envoyer le code de confirmation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }

  // ── Mobile Money : pays + numéro ────────────────────────────────────────
  Widget _buildMobileMoneyFields(_MethodInfo m) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Numéro ${m.label}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => _showCountryPicker(m.color),
          child: Container(
            height: 56, padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200, width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_selectedCountry.flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 4),
              Text(_selectedCountry.dialCode, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.color)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade500, size: 20),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: _numeroController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_selectedCountry.maxDigits)],
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(hint: 'Ex: ${'X' * _selectedCountry.minDigits}', prefixIcon: Icon(Icons.phone_rounded, color: m.color)),
        )),
      ]),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _numeroController,
        builder: (_, v, __) {
          if (v.text.isEmpty) return const SizedBox.shrink();
          return Padding(padding: const EdgeInsets.only(left: 4, top: 6), child: Text('Numéro complet : ${_selectedCountry.dialCode} ${v.text}', style: TextStyle(fontSize: 12, color: m.color, fontWeight: FontWeight.w700)));
        },
      ),
      const SizedBox(height: 4),
    ]);
  }

  // ── Carte Bancaire : numéro, expiry, CVV, titulaire ─────────────────────
  Widget _buildCardFields(_MethodInfo m) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Numéro de carte + badge type
      const Text('Numéro de carte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(height: 8),
      TextField(
        controller: _numeroController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter()],
        onChanged: (v) => setState(() => _cardType = _detectCardType(v)),
        decoration: _inputDecoration(
          hint: '1234 5678 9012 3456',
          prefixIcon: Icon(Icons.credit_card_rounded, color: m.color),
          suffix: _buildCardTypeBadge(),
        ),
      ),
      const SizedBox(height: 16),

      // Date expiration + CVV
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Date d\'expiration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 8),
          TextField(
            controller: _expiryController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryFormatter()],
            decoration: _inputDecoration(hint: 'MM/AA', prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF635BFF), size: 18)),
          ),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_cardType == 'amex' ? 'CID (4 chiffres)' : 'CVV', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 8),
          TextField(
            controller: _cvvController,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_cardType == 'amex' ? 4 : 3)],
            decoration: _inputDecoration(hint: _cardType == 'amex' ? '••••' : '•••', prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF635BFF), size: 18)),
          ),
        ])),
      ]),
      const SizedBox(height: 16),

      // Titulaire
      const Text('Nom du titulaire', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(height: 8),
      TextField(
        controller: _cardHolderController,
        keyboardType: TextInputType.name,
        textCapitalization: TextCapitalization.words,
        decoration: _inputDecoration(hint: 'Ex: Jean Dupont', prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF635BFF))),
      ),
      const SizedBox(height: 8),
      _buildInfoBanner('Paiement sécurisé via CinetPay. Vos données de carte ne sont jamais stockées.', const Color(0xFF635BFF)),
      const SizedBox(height: 16),
    ]);
  }

  // ── Virement bancaire : IBAN/RIB ───────────────────────────────────────
  Widget _buildBankFields(_MethodInfo m) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('IBAN / RIB', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(height: 8),
      TextField(
        controller: _numeroController,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.characters,
        decoration: _inputDecoration(hint: 'Ex: ML01 1234 5678 9012 3456 7890 123', prefixIcon: Icon(Icons.account_balance_rounded, color: m.color)),
      ),
      const SizedBox(height: 16),
    ]);
  }

  // ═══ FORMULAIRE OTP ══════════════════════════════════════════════════════
  Widget _buildOtpSection() {
    final m = _selected!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _navy.withAlpha(8), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: m.color.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.lock_rounded, color: m.color, size: 20)),
          const SizedBox(width: 12),
          const Text('Code de confirmation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)),
        ]),
        if (_destination.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: m.color.withAlpha(15), borderRadius: BorderRadius.circular(12), border: Border.all(color: m.color.withAlpha(50))),
            child: Row(children: [Icon(Icons.info_outline_rounded, color: m.color, size: 20), const SizedBox(width: 12), Expanded(child: Text('Code envoyé à $_destination (valable 15 min)', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)))])),
        ],
        const SizedBox(height: 16),
        const Text('Saisissez le code à 6 chiffres', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 12, color: Color(0xFF0D47A1)),
          decoration: InputDecoration(counterText: '', hintText: '••••••', hintStyle: TextStyle(fontSize: 24, color: Colors.grey.shade300, letterSpacing: 12), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 2))),
        ),
        if (_error != null) ...[const SizedBox(height: 8), Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 16), const SizedBox(width: 6), Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)))])],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _submitting ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Valider la demande de retrait', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: _resendTimer > 0
            ? Text('Renvoyer le code dans ${_resendTimer}s', style: TextStyle(fontSize: 13, color: Colors.grey.shade500))
            : TextButton.icon(onPressed: _submitting ? null : () async { setState(() => _error = null); await _requestOtp(); }, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Renvoyer le code'), style: TextButton.styleFrom(foregroundColor: _accent))),
      ]),
    );
  }

  // ═══ HELPERS ═════════════════════════════════════════════════════════════
  InputDecoration _inputDecoration({required String hint, Widget? prefixIcon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint, prefixIcon: prefixIcon, suffix: suffix, filled: true, fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 2)),
    );
  }

  Widget _channelChip(String value, IconData icon, String label, Color methodColor) {
    final sel = _channel == value;
    return InkWell(
      onTap: () => setState(() => _channel = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: sel ? _accent.withAlpha(18) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? _accent : Colors.grey.shade200, width: sel ? 2 : 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: sel ? _accent : Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: sel ? _accent : Colors.grey.shade600)),
        ]),
      ),
    );
  }

  Widget _buildInfoBanner(String msg, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withAlpha(50), width: 1)),
      child: Row(children: [Icon(Icons.info_outline_rounded, color: color, size: 20), const SizedBox(width: 12), Expanded(child: Text(msg, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)))]),
    );
  }

  Widget? _buildCardTypeBadge() {
    if (_cardType == null) return null;
    final info = {
      'visa': ('VISA', const Color(0xFF1A1F71), const Color(0xFFE8ECF8)),
      'mastercard': ('MC', const Color(0xFFEB001B), const Color(0xFFFEECEC)),
      'amex': ('AMEX', const Color(0xFF007BC1), const Color(0xFFE0F0FA)),
    }[_cardType];
    if (info == null) return null;
    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: Container(
      key: ValueKey(_cardType), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: info.$3, borderRadius: BorderRadius.circular(6)),
      child: Text(info.$1, style: TextStyle(color: info.$2, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
    ));
  }

  void _showCountryPicker(Color accentColor) {
    List<_CountryInfo> filtered = List.from(_kCountries);
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setBS) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Icon(Icons.public_rounded, color: accentColor, size: 22), const SizedBox(width: 10), const Text('Sélectionner un pays', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy))])),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(
              onChanged: (q) => setBS(() { filtered = _kCountries.where((c) => c.name.toLowerCase().contains(q.toLowerCase()) || c.dialCode.contains(q)).toList(); }),
              decoration: InputDecoration(hintText: 'Rechercher...', prefixIcon: Icon(Icons.search_rounded, color: accentColor), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 2))),
            )),
            const SizedBox(height: 8), const Divider(height: 1),
            Expanded(child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final c = filtered[i];
                final sel = c.dialCode == _selectedCountry.dialCode && c.name == _selectedCountry.name;
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                  title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? accentColor : _navy)),
                  subtitle: Text('${c.dialCode}  •  ${c.minDigits}–${c.maxDigits} chiffres', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  trailing: sel ? Icon(Icons.check_circle_rounded, color: accentColor) : null,
                  onTap: () { setState(() { _selectedCountry = c; _numeroController.clear(); }); Navigator.pop(ctx); },
                );
              },
            )),
          ]),
        );
      });
    });
  }
}
