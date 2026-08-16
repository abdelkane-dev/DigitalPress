import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/payment_service.dart';
import '../../core/utils/friendly_error.dart';
import '../reader/reader_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Formatter : espace tous les 4 chiffres → XXXX XXXX XXXX XXXX
// ─────────────────────────────────────────────────────────────────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    if (digits.length > 16) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatter : MM/AA
// ─────────────────────────────────────────────────────────────────────────────
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length > 4) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modèle pays + liste complète
// ─────────────────────────────────────────────────────────────────────────────
class _CountryInfo {
  final String name;
  final String flag;
  final String dialCode;
  final int minDigits;
  final int maxDigits;

  const _CountryInfo({
    required this.name,
    required this.flag,
    required this.dialCode,
    required this.minDigits,
    required this.maxDigits,
  });

  String get display => '$flag  $name ($dialCode)';
}

const List<_CountryInfo> _kCountries = [
  _CountryInfo(
      name: 'Mali', flag: '🇲🇱', dialCode: '+223', minDigits: 8, maxDigits: 8),
  _CountryInfo(
      name: 'Sénégal',
      flag: '🇸🇳',
      dialCode: '+221',
      minDigits: 9,
      maxDigits: 9),
  _CountryInfo(
      name: 'Côte d\'Ivoire',
      flag: '🇨🇮',
      dialCode: '+225',
      minDigits: 10,
      maxDigits: 10),
  _CountryInfo(
      name: 'Burkina Faso',
      flag: '🇧🇫',
      dialCode: '+226',
      minDigits: 8,
      maxDigits: 8),
  _CountryInfo(
      name: 'Niger',
      flag: '🇳🇪',
      dialCode: '+227',
      minDigits: 8,
      maxDigits: 8),
  _CountryInfo(
      name: 'Guinée',
      flag: '🇬🇳',
      dialCode: '+224',
      minDigits: 9,
      maxDigits: 9),
  _CountryInfo(
      name: 'Guinée-Bissau',
      flag: '🇬🇼',
      dialCode: '+245',
      minDigits: 7,
      maxDigits: 9),
  _CountryInfo(
      name: 'Mauritanie',
      flag: '🇲🇷',
      dialCode: '+222',
      minDigits: 8,
      maxDigits: 8),
  _CountryInfo(
      name: 'Togo', flag: '🇹🇬', dialCode: '+228', minDigits: 8, maxDigits: 8),
  _CountryInfo(
      name: 'Bénin',
      flag: '🇧🇯',
      dialCode: '+229',
      minDigits: 8,
      maxDigits: 8),
  _CountryInfo(
      name: 'Ghana',
      flag: '🇬🇭',
      dialCode: '+233',
      minDigits: 9,
      maxDigits: 10),
  _CountryInfo(
      name: 'Nigeria',
      flag: '🇳🇬',
      dialCode: '+234',
      minDigits: 10,
      maxDigits: 11),
  _CountryInfo(
      name: 'Cameroun',
      flag: '🇨🇲',
      dialCode: '+237',
      minDigits: 9,
      maxDigits: 9),
  _CountryInfo(
      name: 'Congo (RDC)',
      flag: '🇨🇩',
      dialCode: '+243',
      minDigits: 9,
      maxDigits: 9),
  _CountryInfo(
      name: 'Congo (Brazza)',
      flag: '🇨🇬',
      dialCode: '+242',
      minDigits: 9,
      maxDigits: 9),
  _CountryInfo(
      name: 'Gabon',
      flag: '🇬🇦',
      dialCode: '+241',
      minDigits: 7,
      maxDigits: 8),
  _CountryInfo(
      name: 'Tchad',
      flag: '🇹🇩',
      dialCode: '+235',
      minDigits: 8,
      maxDigits: 8),
  _CountryInfo(
      name: 'Madagascar',
      flag: '🇲🇬',
      dialCode: '+261',
      minDigits: 9,
      maxDigits: 10),
  _CountryInfo(
      name: 'Maroc',
      flag: '🇲🇦',
      dialCode: '+212',
      minDigits: 9,
      maxDigits: 9),
  _CountryInfo(
      name: 'Algérie',
      flag: '🇩🇿',
      dialCode: '+213',
      minDigits: 9,
      maxDigits: 9),
  _CountryInfo(
      name: 'Tunisie',
      flag: '🇹🇳',
      dialCode: '+216',
      minDigits: 8,
      maxDigits: 8),
  _CountryInfo(
      name: 'France',
      flag: '🇫🇷',
      dialCode: '+33',
      minDigits: 9,
      maxDigits: 9),
  _CountryInfo(
      name: 'Belgique',
      flag: '🇧🇪',
      dialCode: '+32',
      minDigits: 9,
      maxDigits: 10),
  _CountryInfo(
      name: 'Canada',
      flag: '🇨🇦',
      dialCode: '+1',
      minDigits: 10,
      maxDigits: 10),
  _CountryInfo(
      name: 'États-Unis',
      flag: '🇺🇸',
      dialCode: '+1',
      minDigits: 10,
      maxDigits: 10),
];

// ─────────────────────────────────────────────────────────────────────────────
// PaymentScreen
// ─────────────────────────────────────────────────────────────────────────────
class PaymentScreen extends ConsumerStatefulWidget {
  final String? journalId;
  final String journalTitle;
  final double price;
  final PaymentMethodType paymentMethod;
  final String paymentMethodName;
  final int? abonnementId;
  final bool isSubscription;
  final bool isRecharge;

  const PaymentScreen({
    super.key,
    this.journalId,
    required this.journalTitle,
    required this.price,
    required this.paymentMethod,
    required this.paymentMethodName,
    this.abonnementId,
    this.isSubscription = false,
    this.isRecharge = false,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  /// Évite une double navigation (clic sur le bouton + timer automatique)
  /// vers le lecteur après un achat réussi.
  bool _autoOpenedReader = false;
  final _formKey = GlobalKey<FormState>();

  // Mobile Money
  final _phoneController = TextEditingController();
  final _countrySearchController = TextEditingController();
  _CountryInfo _selectedCountry = _kCountries.first; // Mali par défaut

  // Carte bancaire (Stripe)
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();

  // Type de carte détecté en temps réel
  String? _cardType; // 'visa' | 'mastercard' | 'amex' | null

  bool _isProcessing = false;

  // ───────────── helpers ──────────────────────────────────────────────────

  bool get _isMobileMoney =>
      widget.paymentMethod == PaymentMethodType.wave ||
      widget.paymentMethod == PaymentMethodType.orangeMoney ||
      widget.paymentMethod == PaymentMethodType.moovMoney ||
      widget.paymentMethod == PaymentMethodType.samaMoney;

  bool get _isWallet => widget.paymentMethod == PaymentMethodType.wallet;
  bool get _isCard => widget.paymentMethod == PaymentMethodType.stripe;

  /// Détecte le réseau de la carte depuis son numéro brut (sans espaces).
  String? _detectCardType(String raw) {
    final digits = raw.replaceAll(' ', '');
    if (digits.isEmpty) return null;
    // American Express : 34 ou 37
    if (digits.startsWith('34') || digits.startsWith('37')) return 'amex';
    // Mastercard : 51-55 ou 2221-2720
    if (digits.length >= 2) {
      final twoDigit = int.tryParse(digits.substring(0, 2)) ?? 0;
      if (twoDigit >= 51 && twoDigit <= 55) return 'mastercard';
    }
    if (digits.length >= 4) {
      final fourDigit = int.tryParse(digits.substring(0, 4)) ?? 0;
      if (fourDigit >= 2221 && fourDigit <= 2720) return 'mastercard';
    }
    // Visa : commence par 4
    if (digits.startsWith('4')) return 'visa';
    return null;
  }

  Color get _methodColor {
    switch (widget.paymentMethod) {
      case PaymentMethodType.wave:
        return const Color(0xFF1BA9F5);
      case PaymentMethodType.orangeMoney:
        return const Color(0xFFFF6600);
      case PaymentMethodType.moovMoney:
        return const Color(0xFF0033A0);
      case PaymentMethodType.samaMoney:
        return const Color(0xFF00A651);
      case PaymentMethodType.wallet:
        return const Color(0xFF8B5CF6);
      case PaymentMethodType.stripe:
        return const Color(0xFF635BFF);
    }
  }

  IconData get _methodIcon {
    switch (widget.paymentMethod) {
      case PaymentMethodType.wave:
      case PaymentMethodType.orangeMoney:
      case PaymentMethodType.moovMoney:
      case PaymentMethodType.samaMoney:
        return Icons.phone_android_rounded;
      case PaymentMethodType.wallet:
        return Icons.account_balance_wallet_rounded;
      case PaymentMethodType.stripe:
        return Icons.credit_card_rounded;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _countrySearchController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  // ───────────── build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2647),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Paiement',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildOrderSummary(),
            _buildPaymentForm(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ───────────── Header ───────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF0A2647), _methodColor.withAlpha(180)],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(_methodIcon, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            widget.paymentMethodName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _methodColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${widget.price.toStringAsFixed(0)} FCFA',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────── Récapitulatif ─────────────────────────────────────────────

  Widget _buildOrderSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(8),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _methodColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt_long_rounded,
                    color: _methodColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Récapitulatif',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0A2647),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryRow('Journal', widget.journalTitle),
          const Divider(height: 24),
          _buildSummaryRow('ID Transaction', widget.journalId ?? '—'),
          const Divider(height: 24),
          _buildSummaryRow('Méthode', widget.paymentMethodName),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0A2647),
                ),
              ),
              Text(
                '${widget.price.toStringAsFixed(0)} FCFA',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _methodColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A2647),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────── Formulaire adaptatif ─────────────────────────────────────

  Widget _buildPaymentForm() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(8),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre de section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _methodColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_methodIcon, color: _methodColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informations de paiement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0A2647),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Contenu selon le mode
            if (_isMobileMoney) _buildMobileMoneyForm(),
            if (_isWallet) _buildWalletConfirmation(),
            if (_isCard) _buildCardForm(),
          ],
        ),
      ),
    );
  }

  // ── Mobile Money ─────────────────────────────────────────────────────────

  Widget _buildMobileMoneyForm() {
    final String operatorLabel;
    final Color operatorColor = _methodColor;
    final country = _selectedCountry;

    switch (widget.paymentMethod) {
      case PaymentMethodType.wave:
        operatorLabel = 'Numéro Wave';
        break;
      case PaymentMethodType.orangeMoney:
        operatorLabel = 'Numéro Orange Money';
        break;
      case PaymentMethodType.moovMoney:
        operatorLabel = 'Numéro Moov Money';
        break;
      case PaymentMethodType.samaMoney:
        operatorLabel = 'Numéro Sama Money';
        break;
      default:
        operatorLabel = 'Numéro de téléphone';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          operatorLabel,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A2647),
          ),
        ),
        const SizedBox(height: 8),
        // ── Ligne pays + numéro ──────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bouton sélecteur de pays
            GestureDetector(
              onTap: () => _showCountryPicker(operatorColor),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      country.flag,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      country.dialCode,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: operatorColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded,
                        color: Colors.grey.shade500, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Champ numéro
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(country.maxDigits),
                ],
                decoration: _inputDecoration(
                  hint: 'Ex: ${'X' * country.minDigits}',
                  prefixIcon: Icon(Icons.phone_rounded, color: operatorColor),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Entrez votre numéro';
                  }
                  if (v.length < country.minDigits) {
                    return 'Min. ${country.minDigits} chiffres pour ${country.name}';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Numéro complet en aperçu
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _phoneController,
          builder: (_, value, __) {
            final full = '${country.dialCode} ${value.text}';
            if (value.text.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Numéro complet : $full',
                style: TextStyle(
                  fontSize: 12,
                  color: operatorColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildInfoBanner(
          'Vous recevrez une notification sur votre téléphone pour confirmer le paiement.',
          operatorColor,
        ),
      ],
    );
  }

  /// Affiche un Bottom Sheet de sélection de pays avec recherche.
  void _showCountryPicker(Color accentColor) {
    _countrySearchController.clear();
    List<_CountryInfo> filtered = List.from(_kCountries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBS) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Poignée
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Titre
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.public_rounded,
                            color: accentColor, size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          'Sélectionner un pays',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0A2647),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Barre de recherche
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _countrySearchController,
                      onChanged: (q) {
                        setBS(() {
                          filtered = _kCountries
                              .where((c) =>
                                  c.name.toLowerCase().contains(
                                        q.toLowerCase(),
                                      ) ||
                                  c.dialCode.contains(q))
                              .toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Rechercher un pays ou indicatif...',
                        prefixIcon:
                            Icon(Icons.search_rounded, color: accentColor),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.grey.shade200, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  // Liste
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final isSelected =
                            c.dialCode == _selectedCountry.dialCode &&
                                c.name == _selectedCountry.name;
                        return ListTile(
                          leading: Text(
                            c.flag,
                            style: const TextStyle(fontSize: 26),
                          ),
                          title: Text(
                            c.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? accentColor
                                  : const Color(0xFF0A2647),
                            ),
                          ),
                          subtitle: Text(
                            '${c.dialCode}  •  ${c.minDigits}–${c.maxDigits} chiffres',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded,
                                  color: accentColor)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedCountry = c;
                              _phoneController.clear();
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Wallet ───────────────────────────────────────────────────────────────

  Widget _buildWalletConfirmation() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF8B5CF6).withAlpha(20),
                const Color(0xFF8B5CF6).withAlpha(5),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withAlpha(60),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Paiement via Portefeuille',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF0A2647),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Le montant sera débité directement de votre solde interne. Aucune information supplémentaire requise.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoBanner(
          'Assurez-vous d\'avoir un solde suffisant avant de confirmer.',
          const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  // ── Carte bancaire (CinetPay) ────────────────────────────────────────────

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Numéro de carte + indicateur du type
        const Text(
          'Numéro de carte',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A2647),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _CardNumberFormatter(),
          ],
          onChanged: (v) {
            setState(() => _cardType = _detectCardType(v));
          },
          decoration: _inputDecoration(
            hint: '1234 5678 9012 3456',
            prefixIcon:
                const Icon(Icons.credit_card_rounded, color: Color(0xFF635BFF)),
            suffix: _buildCardTypeBadge(),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Entrez le numéro de carte';
            if (v.replaceAll(' ', '').length < 13) {
              return 'Numéro de carte invalide';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Date d'expiration + CVV côte à côte
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date d\'expiration',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A2647),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ExpiryFormatter(),
                    ],
                    decoration: _inputDecoration(
                      hint: 'MM/AA',
                      prefixIcon: const Icon(Icons.calendar_today_rounded,
                          color: Color(0xFF635BFF), size: 18),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requis';
                      if (v.length < 5) return 'Format MM/AA';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cardType == 'amex' ? 'CID (4 chiffres)' : 'CVV',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A2647),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                          _cardType == 'amex' ? 4 : 3),
                    ],
                    decoration: _inputDecoration(
                      hint: _cardType == 'amex' ? '••••' : '•••',
                      prefixIcon: const Icon(Icons.lock_rounded,
                          color: Color(0xFF635BFF), size: 18),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requis';
                      final expected = _cardType == 'amex' ? 4 : 3;
                      if (v.length < expected) {
                        return '$expected chiffres requis';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Nom du titulaire
        const Text(
          'Nom du titulaire',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A2647),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cardHolderController,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDecoration(
            hint: 'Ex: Jean Dupont',
            prefixIcon:
                const Icon(Icons.person_rounded, color: Color(0xFF635BFF)),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Entrez le nom du titulaire';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildInfoBanner(
          'Paiement sécurisé via CinetPay. Vos données de carte ne sont jamais stockées sur nos serveurs.',
          const Color(0xFF635BFF),
        ),
      ],
    );
  }

  // ── Badge type de carte ──────────────────────────────────────────────────

  Widget? _buildCardTypeBadge() {
    if (_cardType == null) return null;

    final Map<String, Map<String, dynamic>> cardInfo = {
      'visa': {
        'label': 'VISA',
        'color': const Color(0xFF1A1F71),
        'bgColor': const Color(0xFFE8ECF8),
        'icon': Icons.credit_card_rounded,
      },
      'mastercard': {
        'label': 'MC',
        'color': const Color(0xFFEB001B),
        'bgColor': const Color(0xFFFEECEC),
        'icon': Icons.credit_card_rounded,
      },
      'amex': {
        'label': 'AMEX',
        'color': const Color(0xFF007BC1),
        'bgColor': const Color(0xFFE0F0FA),
        'icon': Icons.credit_card_rounded,
      },
    };

    final info = cardInfo[_cardType]!;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(_cardType),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: info['bgColor'] as Color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          info['label'] as String,
          style: TextStyle(
            color: info['color'] as Color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ── InputDecoration réutilisable ─────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffix,
    String? prefixText,
    TextStyle? prefixStyle,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      prefix: prefixText != null ? Text(prefixText, style: prefixStyle) : null,
      suffix: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _methodColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  // ── Bandeau info ─────────────────────────────────────────────────────────

  Widget _buildInfoBanner(String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────── Barre du bas ──────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handlePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _methodColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Confirmer — ${widget.price.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ───────────── Logique de paiement ──────────────────────────────────────

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      // Pour le wallet on envoie un téléphone vide (non requis côté backend)
      final phone = _isWallet ? '' : _phoneController.text.trim();

      final session = await ref.read(paymentServiceProvider).initiatePayment(
            publicationId: widget.isRecharge ? null : widget.journalId,
            abonnementId: widget.abonnementId,
            phone: phone,
            amount: widget.price,
            method: widget.paymentMethod,
            isSubscription: widget.isSubscription,
            isRecharge: widget.isRecharge,
          );

      if (!mounted) return;

      if (session != null) {
        // Si la transaction est déjà confirmée (ex: paiement via portefeuille),
        // on affiche immédiatement le succès sans polling inutile.
        if (session.status == 'success' ||
            session.status == 'completed' ||
            session.status == 'paid') {
          _showSuccessDialog();
        } else {
          _showWaitingDialog(session.reference);
        }
      } else {
        throw Exception('Impossible d\'initier la session de paiement.');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _isProcessing = false);
    }
  }

  void _showWaitingDialog(String reference) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PaymentStatusDialog(
        reference: reference,
        onComplete: () {
          Navigator.pop(context);
          _showSuccessDialog();
        },
        onFailed: (msg) {
          Navigator.pop(context);
          _showFailedDialog(msg);
        },
      ),
    );
  }

  /// Ouvre directement le lecteur de l'article acheté (demande explicite :
  /// « une fois un article acheté on rentre directement dans l'article »).
  /// Remplace l'écran de paiement par le lecteur, sans clic supplémentaire.
  void _openPurchasedArticle() {
    if (_autoOpenedReader || widget.isRecharge || widget.journalId == null) {
      return;
    }
    _autoOpenedReader = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          journalId: widget.journalId!,
          isSubscribed: true,
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _methodColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Achat réussi !',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0A2647),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ouverture de votre publication…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext); // ferme le dialog de succès
                  if (!widget.isRecharge) {
                    // Achat : entrée directe dans l'article. Recharge : on
                    // revient simplement à l'écran précédent.
                    _openPurchasedArticle();
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _methodColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(widget.isRecharge ? 'Fermer' : 'Ouvrir l\u2019article'),
              ),
            ),
          ],
        ),
      ),
    );

    // ─── ENTRÉE DIRECTE SANS CLIC (demande explicite) ───────────────────
    // Pour un achat (pas une recharge) : le succès s'affiche brièvement puis
    // le lecteur s'ouvre TOUT SEUL. Le bouton reste disponible pour les
    // impatients (et évite tout blocage si le timer est interrompu).
    if (!widget.isRecharge && widget.journalId != null) {
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (!mounted || _autoOpenedReader) return;
        Navigator.of(context).pop(); // ferme le dialog de succès
        _openPurchasedArticle();
      });
    }
  }

  /// Appelée après fermeture du dialog de succès. Gère le refresh profil
  /// et la fermeture de PaymentScreen, en évitant tout problème async/context.
  void _showFailedDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Paiement échoué',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isProcessing = false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogue d'attente de confirmation (polling)
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentStatusDialog extends ConsumerStatefulWidget {
  final String reference;
  final VoidCallback onComplete;
  final Function(String) onFailed;

  const _PaymentStatusDialog({
    required this.reference,
    required this.onComplete,
    required this.onFailed,
  });

  @override
  ConsumerState<_PaymentStatusDialog> createState() =>
      __PaymentStatusDialogState();
}

class __PaymentStatusDialogState extends ConsumerState<_PaymentStatusDialog> {
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _isCancelled = true;
    super.dispose();
  }

  Future<void> _startPolling() async {
    if (!mounted) return;
    final service = ref.read(paymentServiceProvider);
    final completed = await service.waitForPaymentCompletion(widget.reference);
    if (_isCancelled || !mounted) return;

    if (completed) {
      widget.onComplete();
    } else {
      widget.onFailed('Le paiement n\'a pas pu être validé ou a été refusé.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Attente de confirmation...',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Veuillez valider l\'opération sur votre téléphone et patienter.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
