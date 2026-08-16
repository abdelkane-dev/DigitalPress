import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/publication_service.dart';
import '../../core/services/publisher_verification_service.dart';
import '../../core/exceptions/failures.dart';

/// Étape d'onboarding éditeur (dossier de légitimité, sans effet bloquant
/// sur l'accès à la publication) : admin crée le compte -> accès immédiat
/// et gratuit -> ÉDITEUR REMPLIT CE FORMULAIRE pour prouver la légitimité
/// de son agence -> admin valide/rejette (notif + email, sert au badge
/// « Vérifié »). Le router redirige ici tant que la vérification n'est
/// pas 'approved'.
///
/// Palette orange, cohérente avec le reste de l'espace éditeur.
class PosterVerificationScreen extends ConsumerStatefulWidget {
  const PosterVerificationScreen({super.key});

  @override
  ConsumerState<PosterVerificationScreen> createState() => _PosterVerificationScreenState();
}

class _PosterVerificationScreenState extends ConsumerState<PosterVerificationScreen> {
  static const _orange = Color(0xFFEA580C);
  static const _bg = Color(0xFFFFF7ED);

  final _formKey = GlobalKey<FormState>();
  final _legalCompanyName = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _taxId = TextEditingController();
  final _officialAddress = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _legalRepName = TextEditingController();
  final _legalRepIdNumber = TextEditingController();
  final _pressAccreditation = TextEditingController();
  final _website = TextEditingController();

  String? _idDocumentUrl;
  String? _registrationDocumentUrl;
  String? _additionalDocumentUrl;
  String? _uploadingField;

  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _verification; // null = jamais soumis
  final Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _legalCompanyName, _registrationNumber, _taxId, _officialAddress, _city,
      _country, _phoneNumber, _legalRepName, _legalRepIdNumber,
      _pressAccreditation, _website,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final v = await ref.read(publisherVerificationServiceProvider).getMyVerification();
      _verification = v;
      if (v != null) {
        _legalCompanyName.text = v['legal_company_name'] ?? '';
        _registrationNumber.text = v['registration_number'] ?? '';
        _taxId.text = v['tax_id'] ?? '';
        _officialAddress.text = v['official_address'] ?? '';
        _city.text = v['city'] ?? '';
        _country.text = v['country'] ?? '';
        _phoneNumber.text = v['phone_number'] ?? '';
        _legalRepName.text = v['legal_representative_name'] ?? '';
        _legalRepIdNumber.text = v['legal_representative_id_number'] ?? '';
        _pressAccreditation.text = v['press_accreditation_number'] ?? '';
        _website.text = v['website'] ?? '';
        _idDocumentUrl = v['id_document_url'];
        _registrationDocumentUrl = v['registration_document_url'];
        _additionalDocumentUrl = v['additional_document_url'];
      }
    } catch (_) {
      // Pas de vérification existante ou erreur réseau : on affiche le
      // formulaire vide, l'éditeur pourra réessayer en soumettant.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDocument(String field) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sélection du fichier impossible : $e'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    // ─── CORRECTIF « les documents refusent le téléversement » ──────────
    // Certaines plateformes (web surtout) ne fournissent ni `bytes` ni
    // `path` selon la taille du fichier : on refuse alors explicitement
    // avec un message clair au lieu d'un crash muet « Échec de l'envoi ».
    if ((file.bytes == null || file.bytes!.isEmpty) &&
        (file.path == null || file.path!.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fichier illisible : réessayez avec un document plus petit."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _uploadingField = field);
    try {
      final url = await ref
          .read(publicationServiceProvider)
          .uploadMedia(file.name, filePath: file.path, bytes: file.bytes);
      if (!mounted) return;
      setState(() {
        switch (field) {
          case 'id':
            _idDocumentUrl = url;
            _fieldErrors.remove('id_document_url');
            break;
          case 'registration':
            _registrationDocumentUrl = url;
            _fieldErrors.remove('registration_document_url');
            break;
          case 'additional':
            _additionalDocumentUrl = url;
            _fieldErrors.remove('additional_document_url');
            break;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.length > 140 ? "Échec de l'envoi du document. Réessayez." : msg),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingField = null);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _fieldErrors.clear();
    });

    final isFormValid = _formKey.currentState!.validate();
    bool hasDocError = false;

    if (_idDocumentUrl == null || _idDocumentUrl!.isEmpty) {
      _fieldErrors['id_document_url'] = "La pièce d'identité est obligatoire.";
      hasDocError = true;
    }
    if (_registrationDocumentUrl == null || _registrationDocumentUrl!.isEmpty) {
      _fieldErrors['registration_document_url'] = "Le certificat RCCM est obligatoire.";
      hasDocError = true;
    }

    if (!isFormValid || hasDocError) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez corriger les erreurs indiquées dans le formulaire."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      String websiteText = _website.text.trim();
      if (websiteText.isNotEmpty && !websiteText.startsWith('http://') && !websiteText.startsWith('https://')) {
        websiteText = 'https://$websiteText';
      }

      await ref.read(publisherVerificationServiceProvider).submit({
        'legal_company_name': _legalCompanyName.text.trim(),
        'registration_number': _registrationNumber.text.trim(),
        'tax_id': _taxId.text.trim(),
        'official_address': _officialAddress.text.trim(),
        'city': _city.text.trim(),
        'country': _country.text.trim(),
        'phone_number': _phoneNumber.text.trim(),
        'legal_representative_name': _legalRepName.text.trim(),
        'legal_representative_id_number': _legalRepIdNumber.text.trim(),
        'press_accreditation_number': _pressAccreditation.text.trim(),
        'website': websiteText,
        'id_document_url': _idDocumentUrl,
        'registration_document_url': _registrationDocumentUrl,
        'additional_document_url': _additionalDocumentUrl ?? '',
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      if (e is ServerFailure && e.errors != null && e.errors!.isNotEmpty) {
        setState(() {
          e.errors!.forEach((key, val) {
            if (val is List && val.isNotEmpty) {
              _fieldErrors[key] = val.first.toString();
            } else if (val != null) {
              _fieldErrors[key] = val.toString();
            }
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Champs invalides (${e.errors!.length}). Veuillez vérifier les informations saisies sous chaque champ."),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        final msg = e is Failure ? e.message : e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _orange,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Vérification de votre agence',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.3, fontSize: 20)),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _orange))
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final status = _verification?['status'] as String?;

    if (status == 'pending') {
      return _buildStatusMessage(
        icon: Icons.hourglass_top_rounded,
        color: Colors.amber.shade800,
        title: 'Dossier en cours de vérification',
        message: "Votre dossier a été transmis à l'administrateur. Vous recevrez une "
            "réponse par notification et par email sous 24h.",
      );
    }

    if (status == 'approved') {
      return _buildStatusMessage(
        icon: Icons.verified_rounded,
        color: Colors.green.shade700,
        title: 'Dossier validé !',
        message: "Redirection vers le choix de votre abonnement...",
      );
    }

    // status == 'rejected' ou jamais soumis -> formulaire (pré-rempli si rejeté)
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (status == 'rejected') ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dossier refusé', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red.shade800)),
                const SizedBox(height: 4),
                Text(_verification?['rejection_reason']?.toString() ?? '',
                    style: TextStyle(color: Colors.red.shade700)),
                const SizedBox(height: 4),
                const Text('Corrigez les informations ci-dessous et soumettez à nouveau.',
                    style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ] else ...[
          const Text(
            "Avant de publier, prouvez la légitimité de votre agence de presse. "
            "Un administrateur validera votre dossier sous 24h.",
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 20),
        ],

        if (_fieldErrors.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Des erreurs ont été détectées. Veuillez corriger les ${_fieldErrors.length} champ(s) surligné(s) en rouge.",
                    style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Form(
          key: _formKey,
          child: Column(
            children: [
              _sectionTitle('Identité légale de l\'entreprise'),
              _field(_legalCompanyName, 'Raison sociale exacte *', fieldKey: 'legal_company_name'),
              _field(_registrationNumber, "N° RCCM / registre du commerce *", fieldKey: 'registration_number'),
              _field(_taxId, "NIF / numéro d'identification fiscale *", fieldKey: 'tax_id'),
              _field(_officialAddress, 'Adresse physique complète du siège *', fieldKey: 'official_address', maxLines: 2),
              Row(children: [
                Expanded(child: _field(_city, 'Ville *', fieldKey: 'city')),
                const SizedBox(width: 12),
                Expanded(child: _field(_country, 'Pays *', fieldKey: 'country')),
              ]),
              _field(_phoneNumber, 'Téléphone professionnel *', fieldKey: 'phone_number', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _sectionTitle('Représentant légal'),
              _field(_legalRepName, 'Nom complet du représentant légal *', fieldKey: 'legal_representative_name'),
              _field(_legalRepIdNumber, 'N° CNI / passeport du représentant légal *', fieldKey: 'legal_representative_id_number'),
              const SizedBox(height: 12),
              _sectionTitle('Justificatifs de presse (facultatif)'),
              _field(_pressAccreditation, "N° d'accréditation presse / conseil de presse", fieldKey: 'press_accreditation_number', required: false),
              _field(_website, 'Site web', fieldKey: 'website', keyboardType: TextInputType.url, required: false),
              const SizedBox(height: 12),
              _sectionTitle('Documents à téléverser'),
              _documentPicker(
                'id',
                'id_document_url',
                "Pièce d'identité du représentant légal *",
                _idDocumentUrl,
              ),
              _documentPicker(
                'registration',
                'registration_document_url',
                "Certificat RCCM / registre du commerce *",
                _registrationDocumentUrl,
              ),
              _documentPicker(
                'additional',
                'additional_document_url',
                'Licence de presse ou autre justificatif (facultatif)',
                _additionalDocumentUrl,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(status == 'rejected' ? 'Soumettre à nouveau' : 'Envoyer pour vérification',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 64),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 6),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7C2D12))),
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    required String fieldKey,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = true,
  }) {
    final serverError = _fieldErrors[fieldKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: (val) {
          if (_fieldErrors.containsKey(fieldKey)) {
            setState(() => _fieldErrors.remove(fieldKey));
          }
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: serverError != null ? Colors.redAccent : Colors.grey.shade300,
            ),
          ),
          errorText: serverError,
          errorStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 12),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
            : null,
      ),
    );
  }

  Widget _documentPicker(String field, String apiKey, String label, String? currentUrl) {
    final isUploading = _uploadingField == field;
    final docError = _fieldErrors[apiKey];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: isUploading
                ? null
                : () {
                    if (_fieldErrors.containsKey(apiKey)) {
                      setState(() => _fieldErrors.remove(apiKey));
                    }
                    _pickDocument(field);
                  },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: docError != null
                      ? Colors.redAccent
                      : (currentUrl != null ? Colors.green.shade400 : Colors.grey.shade300),
                  width: docError != null ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    currentUrl != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                    color: currentUrl != null
                        ? Colors.green.shade600
                        : (docError != null ? Colors.redAccent : _orange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      currentUrl != null ? '$label — document envoyé ✓' : label,
                      style: TextStyle(color: docError != null ? Colors.redAccent : Colors.black87),
                    ),
                  ),
                  if (isUploading)
                    const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _orange),
                    ),
                ],
              ),
            ),
          ),
          if (docError != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                docError,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
