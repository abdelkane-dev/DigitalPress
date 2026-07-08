import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/publication_service.dart';
import '../../model/publication.dart';

class EditArticleScreen extends ConsumerStatefulWidget {
  final Publication publication;

  const EditArticleScreen({super.key, required this.publication});

  @override
  ConsumerState<EditArticleScreen> createState() => _EditArticleScreenState();
}

class _EditArticleScreenState extends ConsumerState<EditArticleScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController titleController;
  late TextEditingController summaryController;
  late TextEditingController contentController;
  late TextEditingController priceController;
  late TextEditingController tagsController;
  late TextEditingController coverUrlController;
  late TextEditingController pdfUrlController;

  int? selectedCategoryId;
  late String selectedType;
  late bool isFree;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(text: widget.publication.title);
    summaryController = TextEditingController(text: widget.publication.description);
    contentController = TextEditingController(text: widget.publication.content);
    priceController = TextEditingController(text: widget.publication.prix.toStringAsFixed(0));
    tagsController = TextEditingController(text: widget.publication.tags.join(', '));
    coverUrlController = TextEditingController(text: widget.publication.coverImage);
    pdfUrlController = TextEditingController(text: widget.publication.fileUrl);

    selectedCategoryId = widget.publication.categoryId;
    selectedType = widget.publication.pubType;
    isFree = widget.publication.isFree;
  }

  @override
  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    contentController.dispose();
    priceController.dispose();
    tagsController.dispose();
    coverUrlController.dispose();
    pdfUrlController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une catégorie.'), backgroundColor: Colors.red),
      );
      return;
    }

    final data = {
      'title': titleController.text.trim(),
      'description': summaryController.text.trim(),
      'content': contentController.text.trim(),
      'category': selectedCategoryId,
      'pub_type': selectedType,
      'prix': isFree ? 0.0 : double.parse(priceController.text.trim()),
      'is_free': isFree,
      'tags': tagsController.text.trim(),
      'cover_image': coverUrlController.text.trim(),
      'file_url': pdfUrlController.text.trim(),
    };

    try {
      await ref
          .read(publisherPublicationsListProvider.notifier)
          .updatePublication(widget.publication.id, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publication mise à jour avec succès ! ✓'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Modifier article'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black12,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: _inputDecoration('Titre de la publication', Icons.title),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 14),

                categoriesAsync.when(
                  data: (catList) {
                    if (catList.isEmpty) return const Text('Aucune catégorie disponible.');
                    selectedCategoryId ??= catList.first['id'] as int?;
                    return DropdownButtonFormField<int>(
                      initialValue: selectedCategoryId,
                      decoration: _inputDecoration('Catégorie', Icons.category),
                      items: catList.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['id'] as int,
                          child: Text(cat['name']?.toString() ?? ''),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedCategoryId = value;
                          });
                        }
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, __) => Text('Erreur catégories : $e'),
                ),

                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: _inputDecoration('Type de publication', Icons.layers_outlined),
                  items: const [
                    DropdownMenuItem(value: 'article', child: Text('Article')),
                    DropdownMenuItem(value: 'magazine', child: Text('Magazine')),
                    DropdownMenuItem(value: 'journal', child: Text('Journal')),
                    DropdownMenuItem(value: 'report', child: Text('Rapport')),
                    DropdownMenuItem(value: 'ebook', child: Text('E-book')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedType = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: coverUrlController,
                  decoration: _inputDecoration('URL de l\'image de couverture', Icons.image_outlined),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: pdfUrlController,
                  decoration: _inputDecoration('URL du fichier PDF', Icons.picture_as_pdf_outlined),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                ),

                const SizedBox(height: 14),

                SwitchListTile(
                  title: const Text('Contenu Gratuit'),
                  subtitle: const Text('Les lecteurs peuvent lire cet article sans payer'),
                  value: isFree,
                  activeThumbColor: Colors.orange.shade700,
                  onChanged: (val) {
                    setState(() {
                      isFree = val;
                      if (val) priceController.text = '0';
                    });
                  },
                ),

                if (!isFree) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration('Prix individuel (FCFA)', Icons.payments_outlined),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requis';
                      if (double.tryParse(v) == null) return 'Nombre invalide';
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 14),

                TextFormField(
                  controller: tagsController,
                  decoration: _inputDecoration('Tags (séparés par des virgules)', Icons.local_offer_outlined),
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: summaryController,
                  maxLines: 3,
                  decoration: _inputDecoration('Résumé court / Description', Icons.short_text_rounded),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: contentController,
                  minLines: 8,
                  maxLines: 12,
                  decoration: _inputDecoration(
                    'Contenu complet de l’article (Format Markdown supporté)',
                    Icons.description,
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Enregistrer les modifications'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}