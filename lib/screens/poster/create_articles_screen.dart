import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/services/publication_service.dart';

class CreateArticleScreen extends ConsumerStatefulWidget {
  const CreateArticleScreen({super.key});

  @override
  ConsumerState<CreateArticleScreen> createState() =>
      _CreateArticleScreenState();
}

class _CreateArticleScreenState extends ConsumerState<CreateArticleScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController summaryController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  final TextEditingController priceController =
      TextEditingController(text: '0');
  final TextEditingController tagsController = TextEditingController();
  final TextEditingController coverUrlController = TextEditingController(
    text:
        'https://images.unsplash.com/photo-1504711434969-e33886168f5c?auto=format&fit=crop&w=800&q=80',
  );
  final TextEditingController pdfUrlController = TextEditingController(
    text:
        'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
  );

  final TextEditingController categoryController = TextEditingController();
  String selectedType = 'article';
  bool isFree = true;

  @override
  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    contentController.dispose();
    priceController.dispose();
    tagsController.dispose();
    coverUrlController.dispose();
    pdfUrlController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  void _insertFormatting(String prefix, {String suffix = ''}) {
    final text = contentController.text;
    final selection = contentController.selection;

    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';

    contentController.text = text.replaceRange(start, end, replacement);
    contentController.selection = TextSelection.collapsed(
      offset: start + prefix.length + selectedText.length,
    );
  }

  Future<void> _handleFileUpload() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // Images
          'jpg', 'jpeg', 'png', 'gif', 'webp',
          // Videos
          'mp4', 'avi', 'mov', 'mkv', 'flv', 'wmv', 'webm',
          // Documents
          'pdf', 'doc', 'docx', 'txt', 'xlsx', 'xls',
        ],
        allowMultiple: true, // Allow selecting multiple files
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          final filePath = file.path!;
          final fileName = file.name;
          final extension = fileName.split('.').last.toLowerCase();

          String contentToAdd = '';

          if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
            // Image
            contentToAdd = '![Image: $fileName]($filePath)\n\n';
          } else if (['mp4', 'avi', 'mov', 'mkv', 'flv', 'wmv', 'webm']
              .contains(extension)) {
            // Video
            contentToAdd = '🎬 **Vidéo**: [$fileName]($filePath)\n\n---\n\n';
          } else if (extension == 'txt') {
            // Read TXT file directly
            try {
              final txtFile = File(filePath);
              final textContent = await txtFile.readAsString();
              contentToAdd = '$textContent\n\n---\n\n';
            } catch (e) {
              contentToAdd = '📄 **Texte** ($fileName)\n\n---\n\n';
            }
          } else if (extension == 'pdf') {
            contentToAdd = '📕 **PDF**: [$fileName]($filePath)\n\n---\n\n';
          } else if (['doc', 'docx'].contains(extension)) {
            contentToAdd =
                '📝 **Document**: [$fileName]($filePath) (convertissez en PDF pour extraction)\n\n---\n\n';
          } else if (['xlsx', 'xls'].contains(extension)) {
            contentToAdd =
                '📊 **Feuille de calcul**: [$fileName]($filePath)\n\n---\n\n';
          } else {
            contentToAdd = '📎 **Fichier**: [$fileName]($filePath)\n\n';
          }

          setState(() {
            contentController.text = contentController.text + contentToAdd;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${result.files.length} fichier(s) ajouté(s) au contenu'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submit(String status) async {
    if (!_formKey.currentState!.validate()) return;

    final categoryName = categoryController.text.trim();
    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez renseigner une catégorie.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final publicationService = ref.read(publicationServiceProvider);
    final categories = await ref.read(categoriesProvider.future);
    final existingCategory = categories.where((cat) {
      final name = (cat['name'] ?? '').toString().toLowerCase();
      return name == categoryName.toLowerCase();
    }).toList();

    int? categoryId;
    if (existingCategory.isNotEmpty) {
      categoryId = (existingCategory.first['id'] as int?);
    } else {
      final createdCategory =
          await publicationService.createCategory(categoryName);
      categoryId = (createdCategory['id'] as int?);
    }

    if (categoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Impossible de récupérer la catégorie.'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    final data = {
      'title': titleController.text.trim(),
      'description': summaryController.text.trim(),
      'content': contentController.text.trim(),
      'category': categoryId,
      'pub_type': selectedType,
      'prix': isFree ? 0.0 : double.parse(priceController.text.trim()),
      'is_free': isFree,
      'status': status,
      'tags': tagsController.text.trim(),
      'cover_image': coverUrlController.text.trim(),
      'file_url': pdfUrlController.text.trim(),
    };

    try {
      await ref
          .read(publisherPublicationsListProvider.notifier)
          .createPublication(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'published'
                  ? 'Article publié avec succès ! ✓'
                  : 'Article sauvegardé en brouillon.',
            ),
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

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Créer un article'),
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
                  decoration:
                      _inputDecoration('Titre de la publication', Icons.title),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: categoryController,
                  decoration: _inputDecoration(
                    'Catégorie',
                    Icons.category,
                  ).copyWith(
                    hintText: 'Ex: Politique, Tech, Culture',
                    helperText:
                        'Le nom sera utilisé pour créer ou retrouver la catégorie.',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Champ requis'
                      : null,
                ),

                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: _inputDecoration(
                      'Type de publication', Icons.layers_outlined),
                  items: const [
                    DropdownMenuItem(value: 'article', child: Text('Article')),
                    DropdownMenuItem(
                        value: 'magazine', child: Text('Magazine')),
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
                  decoration: _inputDecoration(
                      'URL de l\'image de couverture', Icons.image_outlined),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: pdfUrlController,
                  decoration: _inputDecoration(
                      'URL du fichier PDF', Icons.picture_as_pdf_outlined),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                ),

                const SizedBox(height: 14),

                SwitchListTile(
                  title: const Text('Contenu Gratuit'),
                  subtitle: const Text(
                      'Les lecteurs peuvent lire cet article sans payer'),
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
                    decoration: _inputDecoration(
                        'Prix individuel (FCFA)', Icons.payments_outlined),
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
                  decoration: _inputDecoration(
                          'Tags (séparés par des virgules)',
                          Icons.local_offer_outlined)
                      .copyWith(
                    hintText: 'mali,actualité,économie',
                  ),
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: summaryController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                      'Résumé court / Description', Icons.short_text_rounded),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 14),

                // Toolbar formatting
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Wrap(
                    spacing: 4,
                    children: [
                      _buildToolbarButton(
                        icon: Icons.title,
                        tooltip: 'Titre',
                        onTap: () => _insertFormatting('# '),
                      ),
                      _buildToolbarButton(
                        icon: Icons.subtitles,
                        tooltip: 'Sous-titre',
                        onTap: () => _insertFormatting('## '),
                      ),
                      _buildToolbarButton(
                        icon: Icons.format_list_bulleted,
                        tooltip: 'Liste',
                        onTap: () => _insertFormatting('- '),
                      ),
                      _buildToolbarButton(
                        icon: Icons.format_quote,
                        tooltip: 'Citation',
                        onTap: () => _insertFormatting('> '),
                      ),
                      _buildToolbarButton(
                        icon: Icons.horizontal_rule,
                        tooltip: 'Séparateur',
                        onTap: () => _insertFormatting('\n---\n'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Stack(
                  children: [
                    TextFormField(
                      controller: contentController,
                      minLines: 8,
                      maxLines: 12,
                      decoration: _inputDecoration(
                        'Contenu complet de l\'article (Format Markdown supporté)',
                        Icons.description,
                      ).copyWith(
                        hintText:
                            'Glissez-déposez images, vidéos, PDF, documents...',
                        helperText:
                            'Supporté: Images (JPG, PNG, GIF), Vidéos (MP4, AVI), Documents (PDF, DOC, TXT)',
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Champ requis'
                          : null,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Tooltip(
                        message:
                            'Ajouter images, vidéos, PDF ou documents\n\nFormats: JPG, PNG, GIF, MP4, AVI, PDF, DOC, TXT, etc.',
                        child: IconButton(
                          icon: const Icon(Icons.attach_file),
                          onPressed: _handleFileUpload,
                          tooltip: 'Ajouter du contenu multimédia',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _submit('draft'),
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer brouillon'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _submit('published'),
                      icon: const Icon(Icons.publish),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                      label: const Text('Publier l\'article'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
