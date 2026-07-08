import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/abonnement_service.dart';
import '../../model/abonnement.dart';

class ManagePlansScreen extends ConsumerStatefulWidget {
  const ManagePlansScreen({super.key});

  @override
  ConsumerState<ManagePlansScreen> createState() => _ManagePlansScreenState();
}

class _ManagePlansScreenState extends ConsumerState<ManagePlansScreen> {
  @override
  Widget build(BuildContext context) {
    final plansState = ref.watch(publisherPlansListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Mes Plans d\'abonnement'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(publisherPlansListProvider.notifier).loadPlans(),
          ),
        ],
      ),
      body: plansState.when(
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_outline_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun plan d\'abonnement actif',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2647)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Créez des plans pour permettre à vos lecteurs\nde s\'abonner à vos publications.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showPlanDialog(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Créer mon premier plan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _buildPlanCard(context, plan);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur : $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(publisherPlansListProvider.notifier).loadPlans(),
                child: const Text('Réessayer'),
              )
            ],
          ),
        ),
      ),
      floatingActionButton: plansState.hasValue && plansState.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showPlanDialog(context),
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau Plan'),
            )
          : null,
    );
  }

  Widget _buildPlanCard(BuildContext context, AbonnementPlan plan) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withAlpha(8),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: plan.isActive ? Colors.green.withAlpha(20) : Colors.grey.withAlpha(40),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of Card
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2647),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Période : ${plan.periodLabel}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${plan.prix.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2C74B3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: plan.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        plan.isActive ? 'Actif' : 'Inactif',
                        style: TextStyle(
                          color: plan.isActive ? Colors.green.shade700 : Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Features/Description
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan.description.isNotEmpty) ...[
                  Text(
                    plan.description,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                ],
                if (plan.featuresList.isNotEmpty) ...[
                  const Text(
                    'Fonctionnalités incluses :',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A2647)),
                  ),
                  const SizedBox(height: 8),
                  ...plan.featuresList.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Actions footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showPlanDialog(context, plan: plan),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF2C74B3)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmDeletePlan(context, plan),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showPlanDialog(BuildContext context, {AbonnementPlan? plan}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: plan?.name ?? '');
    final descController = TextEditingController(text: plan?.description ?? '');
    final prixController = TextEditingController(text: plan != null ? plan.prix.toStringAsFixed(0) : '');
    final featuresController = TextEditingController(text: plan?.features ?? '');
    String selectedPeriod = plan?.period ?? 'monthly';
    bool isActive = plan?.isActive ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(plan == null ? 'Nouveau Plan d\'abonnement' : 'Modifier le Plan'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nom du plan', hintText: 'Ex: Premium Mensuel'),
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: prixController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Prix (FCFA)', suffixText: 'FCFA'),
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPeriod,
                      decoration: const InputDecoration(labelText: 'Fréquence de facturation'),
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('Mensuel')),
                        DropdownMenuItem(value: 'quarterly', child: Text('Trimestriel')),
                        DropdownMenuItem(value: 'yearly', child: Text('Annuel')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedPeriod = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: featuresController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Fonctionnalités (une par ligne)',
                        hintText: 'Accès illimité\nLecture hors-ligne\nArchives incluses',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Plan actif'),
                      subtitle: const Text('Permet aux utilisateurs de s\'abonner à ce plan'),
                      value: isActive,
                      activeThumbColor: Colors.orange.shade700,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final data = {
                      'name': nameController.text.trim(),
                      'prix': double.parse(prixController.text.trim()),
                      'period': selectedPeriod,
                      'description': descController.text.trim(),
                      'features': featuresController.text.trim(),
                      'is_active': isActive,
                    };

                    try {
                      if (plan == null) {
                        await ref.read(publisherPlansListProvider.notifier).createPlan(data);
                      } else {
                        await ref.read(publisherPlansListProvider.notifier).updatePlan(plan.id, data);
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              plan == null ? 'Plan créé avec succès !' : 'Plan mis à jour avec succès !',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        });
      },
    );
  }

  void _confirmDeletePlan(BuildContext context, AbonnementPlan plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le plan ?'),
          content: Text('Voulez-vous vraiment supprimer le plan d\'abonnement "${plan.name}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(publisherPlansListProvider.notifier).deletePlan(plan.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plan supprimé avec succès !'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }
}
