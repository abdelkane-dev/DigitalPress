import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/auth_service.dart';

/// Page Aide & Support adaptée selon le type d'utilisateur connecté :
/// - Admin : FAQ admin, couleur navy (#0A2647)
/// - Éditeur : FAQ éditeur, couleur orange (#EA580C)
/// - Lecteur : FAQ lecteur, couleur bleu (#2C74B3)
class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final isPublisher = user?.isPublisher ?? false;

    // Couleur et FAQ adaptées au rôle
    final Color color;
    final String greeting;
    final String roleLabel;
    final List<(String, String)> faqItems;

    if (isAdmin) {
      color = const Color(0xFF0A2647);
      greeting = "Besoin d'aide pour gérer la plateforme ?";
      roleLabel = 'Admin';
      faqItems = _adminFaq;
    } else if (isPublisher) {
      color = const Color(0xFFEA580C);
      greeting = "Besoin d'aide pour votre activité d'éditeur ?";
      roleLabel = 'Éditeur';
      faqItems = _publisherFaq;
    } else {
      color = const Color(0xFF2C74B3);
      greeting = "Besoin d'aide pour naviguer sur DigitalPress ?";
      roleLabel = 'Lecteur';
      faqItems = _readerFaq;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide & Support'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bannière role
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(Icons.support_agent_rounded, color: color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          roleLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // FAQ
          Text('Questions fréquentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 8),
          ...faqItems.map((f) => _FaqTile(question: f.$1, answer: f.$2, accentColor: color)),

          const SizedBox(height: 24),

          // Documents légaux
          Text('Documents légaux', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 8),
          _LinkTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialité',
            onTap: () => _showLegalSheet(context, 'Politique de confidentialité', _privacyPolicyText),
          ),
          _LinkTile(
            icon: Icons.description_outlined,
            title: "Conditions générales d'utilisation",
            onTap: () => _showLegalSheet(context, "Conditions générales d'utilisation", _termsText),
          ),

          const SizedBox(height: 24),

          // Contact
          Text('Nous contacter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 8),
          _LinkTile(
            icon: Icons.email_outlined,
            title: 'Envoyer un email au support',
            subtitle: 'support@digitalpress-ml.com',
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: 'support@digitalpress-ml.com',
                query: 'subject=${Uri.encodeComponent("[$roleLabel] Demande de support")}',
              );
              await launchUrl(uri);
            },
          ),
          _LinkTile(
            icon: Icons.language_rounded,
            title: 'Site web DigitalPress',
            subtitle: 'www.digitalpress-ml.com',
            onTap: () => launchUrl(Uri.parse('https://www.digitalpress-ml.com')),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showLegalSheet(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(content, style: const TextStyle(height: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── FAQ PAR RÔLE ─────────────────────────────────────────────────────────

const List<(String, String)> _readerFaq = [
  (
    "Comment créer un compte DigitalPress ?",
    "Appuyez sur « S'inscrire » depuis l'écran de connexion. Choisissez votre rôle "
        "(Lecteur ou Éditeur), remplissez vos informations et validez votre email avec "
        "le code OTP reçu. Votre compte est actif immédiatement.",
  ),
  (
    "Comment acheter une publication ?",
    "Ouvrez une publication payante, appuyez sur « Acheter ». Choisissez votre moyen "
        "de paiement (Mobile Money Wave/Orange/Moov ou carte bancaire), suivez les "
        "étapes et votre contenu sera débloqué instantanément.",
  ),
  (
    "Comment fonctionne l'abonnement à un éditeur ?",
    "Rendez-vous sur le profil d'un éditeur, appuyez sur « S'abonner ». Choisissez "
        "une formule (hebdomadaire, mensuelle, trimestrielle, annuelle) et payez. "
        "Vous accédez alors à tout le contenu réservé aux abonnés de cet éditeur.",
  ),
  (
    "Comment fonctionne le portefeuille ?",
    "Votre portefeuille accumulate les gains de vos achats et abonnements. Vous pouvez "
        "le recharger depuis votre profil pour acheter du contenu sans saisir vos "
        "informations de paiement à chaque fois.",
  ),
  (
    "J'ai oublié mon mot de passe, que faire ?",
    "Sur l'écran de connexion, appuyez sur « Mot de passe oublié ? ». Saisissez "
        "votre email, recevez un code OTP par email, puis choisissez un nouveau mot "
        "de passe. Le code expire dans 10 minutes.",
  ),
  (
    "Comment contacter le support ?",
    "Envoyez un email à support@digitalpress-ml.com depuis l'onglet « Nous contacter "
        "ci-dessous ou depuis votre client email. Nous répondons sous 24h ouvrées.",
  ),
];

const List<(String, String)> _publisherFaq = [
  (
    "Pourquoi mon compte est-il bloqué après sa création par l'admin ?",
    "Un compte éditeur créé par l'administrateur a un accès immédiat à la "
        "publication — aucun paiement n'est jamais requis. Il doit seulement passer par la "
        "vérification de légitimité (documents légaux), une protection contre les faux comptes.",
  ),
  (
    "Combien de temps prend la vérification ?",
    "Sous 24h en général. Vous recevez une notification et un email dès qu'une décision est prise.",
  ),
  (
    "Comment publier un article ?",
    "Depuis le menu « Créer un article » : remplissez le titre, la catégorie, le contenu "
        "(texte + images/vidéos/PDF via l'icone 📎). Vous pouvez sauvegarder en brouillon "
        "ou publier directement. Utilisez le bouton « Aperçu » pour vérifier avant publier.",
  ),
  (
    "Comment mes lecteurs s'abonnent-ils à mon contenu ?",
    "Créez vos propres offres d'abonnement depuis « Mes offres » : elles apparaissent "
        "ensuite sur votre profil public, visible par tous les lecteurs.",
  ),
  (
    "Comment mettre une publication à la une ?",
    "Depuis vos statistiques, sélectionnez une publication et choisissez « Mettre à la une ». "
        "C'est un service payant (5 000 FCFA/7j, 8 000 FCFA/14j, 12 000 FCFA/30j) "
        "payé depuis votre solde éditeur ou par mobile money.",
  ),
  (
    "Quand suis-je payé pour mes ventes ?",
    "Consultez votre solde et faites une demande de retrait depuis votre espace "
        "comptabilité éditeur. Le paiement est traité automatiquement chaque nuit.",
  ),
  (
    "Dois-je payer un abonnement pour publier sur DigitalPress ?",
    "Non, jamais. L'accès est ouvert dès la création de votre compte. Votre palier "
        "(Basique, Standard, Premium) progresse automatiquement selon votre nombre d'abonnés, "
        "de publications et de ventes — la plateforme se rémunère uniquement via une "
        "commission sur vos ventes.",
  ),
  (
    "Comment modifier ma photo de profil ou ma couverture ?",
    "Allez sur votre profil éditeur, touchez l'icone de modification. Vous pouvez "
        "changer votre photo, votre couverture, votre bio et les informations de votre entreprise.",
  ),
];

const List<(String, String)> _adminFaq = [
  (
    "Comment créer un compte éditeur ?",
    "Depuis « Créer un éditeur ». Le compte est actif immédiatement après création — aucun "
        "paiement d'abonnement n'est requis. La vérification du dossier légal sert uniquement "
        "au badge de légitimité, pas à débloquer l'accès.",
  ),
  (
    "Que se passe-t-il si je rejette une vérification ?",
    "L'éditeur reçoit une notification et un email avec le motif, et peut corriger puis "
        "soumettre à nouveau son dossier.",
  ),
  (
    "Puis-je réactiver un éditeur banni ?",
    "Oui : la réactivation est immédiate, aucun abonnement à payer — il ne s'agit "
        "que de lever la suspension du compte.",
  ),
  (
    "Comment fonctionne la comptabilité ?",
    "L'onglet Comptabilité affiche le journal général, les soldes éditeurs et les "
        "remboursements. Les écritures comptables sont générées automatiquement "
        "à chaque transaction (achat, abonnement, retrait, commission).",
  ),
  (
    "Comment gérer les retraits des éditeurs ?",
    "Depuis Comptabilité > Soldes éditeurs, vous pouvez valider ou refuser les demandes "
        "de retrait. Un OTP est envoyé par email pour confirmer chaque opération.",
  ),
  (
    "Comment configurer CinetPay ?",
    "Ajoutez vos clés API CinetPay (API_KEY, SITE_ID, SECRET) dans le fichier .env "
        "du backend. CinetPay supporte Wave, Orange Money, Moov Money et les cartes "
        "bancaires pour tout l'Afrique de l'Ouest.",
  ),
];

const String _privacyPolicyText = '''
DigitalPress collecte les données strictement nécessaires au fonctionnement du service : informations de compte (nom, email, téléphone), contenu publié, historique de transactions, et données techniques (journaux d'erreurs).

Ces données ne sont jamais vendues à des tiers. Elles sont utilisées uniquement pour fournir le service, traiter les paiements, et assurer la sécurité de la plateforme.

Vous pouvez à tout moment demander la suppression de votre compte depuis votre profil, ce qui efface vos données personnelles identifiables.

Pour toute question, contactez support@digitalpress-ml.com.
''';

const String _termsText = '''
En utilisant DigitalPress, vous acceptez de publier ou consulter du contenu dans le respect des lois en vigueur. Les éditeurs sont seuls responsables du contenu qu'ils publient.

Les comptes éditeur ont un accès immédiat à la publication, sous réserve d'une vérification de légitimité. La plateforme se réserve le droit de suspendre tout compte en cas de non-respect de ces conditions.

Les prix affichés concernent uniquement les achats et abonnements des lecteurs. Les remboursements suivent la politique décrite dans votre espace de paiement.
''';

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  final Color accentColor;
  const _FaqTile({required this.question, required this.answer, this.accentColor = const Color(0xFF0A2647)});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        iconColor: accentColor,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(answer, style: const TextStyle(color: Colors.black54, height: 1.4))],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _LinkTile({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
