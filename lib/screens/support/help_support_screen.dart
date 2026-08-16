import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/auth_service.dart';

/// Remplace, pour Admin et Éditeur, l'ancienne page "Fonctionnalités à
/// venir" sur le 2e onglet de la barre de navigation. Contenu utile et
/// distinct de tout le reste : FAQ par rôle, politique de confidentialité,
/// conditions d'utilisation, contact support — comble aussi une exigence
/// App Store/Play Store (politique de confidentialité accessible in-app).
class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final color = isAdmin ? const Color(0xFF0A2647) : const Color(0xFFEA580C);
    final faqItems = isAdmin ? _adminFaq : _publisherFaq;

    return Scaffold(
      appBar: AppBar(title: const Text('Aide & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.support_agent_rounded, color: color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isAdmin
                        ? "Besoin d'aide pour gérer la plateforme ?"
                        : "Besoin d'aide pour votre activité d'éditeur ?",
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Questions fréquentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...faqItems.map((f) => _FaqTile(question: f.$1, answer: f.$2)),
          const SizedBox(height: 24),
          const Text('Documents légaux', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
          const Text('Nous contacter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _LinkTile(
            icon: Icons.email_outlined,
            title: 'Envoyer un email au support',
            subtitle: 'support@digitalpress.local',
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: 'support@digitalpress.local',
                query: 'subject=${Uri.encodeComponent(isAdmin ? "[Admin]" : "[Éditeur]")} Demande de support',
              );
              await launchUrl(uri);
            },
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
    "Comment mes lecteurs s'abonnent-ils à mon contenu ?",
    "Créez vos propres offres d'abonnement depuis votre espace éditeur : elles apparaissent "
        "ensuite sur votre profil public, visible par tous les lecteurs.",
  ),
  (
    "Quand suis-je payé pour mes ventes ?",
    "Consultez votre solde et faites une demande de retrait depuis votre espace comptabilité éditeur.",
  ),
  (
    "Dois-je payer un abonnement pour publier sur DigitalPress ?",
    "Non, jamais. L'accès est ouvert dès la création de votre compte. Votre palier "
        "(Basique, Standard, Premium) progresse automatiquement selon votre nombre d'abonnés, "
        "de publications et de ventes — la plateforme se rémunère uniquement via une "
        "commission sur vos ventes.",
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
];

const String _privacyPolicyText = '''
DigitalPress collecte les données strictement nécessaires au fonctionnement du service : informations de compte (nom, email, téléphone), contenu publié, historique de transactions, et données techniques (journaux d'erreurs).

Ces données ne sont jamais vendues à des tiers. Elles sont utilisées uniquement pour fournir le service, traiter les paiements, et assurer la sécurité de la plateforme.

Vous pouvez à tout moment demander la suppression de votre compte depuis votre profil, ce qui efface vos données personnelles identifiables.

Pour toute question, contactez support@digitalpress.local.
''';

const String _termsText = '''
En utilisant DigitalPress, vous acceptez de publier ou consulter du contenu dans le respect des lois en vigueur. Les éditeurs sont seuls responsables du contenu qu'ils publient.

Les comptes éditeur ont un accès immédiat à la publication, sous réserve d'une vérification de légitimité. La plateforme se réserve le droit de suspendre tout compte en cas de non-respect de ces conditions.

Les prix affichés concernent uniquement les achats et abonnements des lecteurs. Les remboursements suivent la politique décrite dans votre espace de paiement.
''';

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

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
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
