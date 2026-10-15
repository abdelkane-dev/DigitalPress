import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import '../../core/services/publication_service.dart';
import '../../core/exceptions/failures.dart';
import '../../core/utils/media_validation.dart';

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
  final TextEditingController coverUrlController = TextEditingController();
  final TextEditingController categoryNameController = TextEditingController();

  String selectedType = 'article';
  bool isFree = true;
  bool isSubscriberExclusive = false;
  bool _isUploading = false;
  String _coverType = 'image'; // 'image', 'video', 'url'
  String _coverVideoUrl = '';

  PlatformFile? selectedCoverImageFile;
  PlatformFile? selectedCoverVideoFile;

  @override
  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    contentController.dispose();
    priceController.dispose();
    tagsController.dispose();
    coverUrlController.dispose();
    categoryNameController.dispose();
    super.dispose();
  }

  /// ⚠️ CORRECTIF CRITIQUE : Support universel Web, Android et iOS
  /// Lit les bytes directement, ou lit le fichier local si bytes est null.
  Future<void> _pickCoverImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      var file = result.files.single;

      // Fallback lecture bytes sur Android / iOS si withData n'a pas rempli bytes
      if ((file.bytes == null || file.bytes!.isEmpty) &&
          !kIsWeb &&
          file.path != null &&
          file.path!.isNotEmpty) {
        try {
          final readBytes = await File(file.path!).readAsBytes();
          file = PlatformFile(
            name: file.name,
            size: readBytes.length,
            bytes: readBytes,
            path: file.path,
          );
        } catch (_) {}
      }

      // Validation taille
      final error = validateCoverImage(file);
      if (error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
        return;
      }

      // S'assurer qu'on a bien les bytes
      if (file.bytes == null || file.bytes!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de lire le fichier. Réessayez.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        selectedCoverImageFile = file;
        coverUrlController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur sélection image : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickCoverVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: false, // Vidéo trop lourde pour les bytes
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;

      final sizeError = validateCoverVideoSize(file);
      if (sizeError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sizeError), backgroundColor: Colors.red),
        );
        return;
      }

      // ⚠️ Pas de videoDuration() — on ne vérifie que la taille
      setState(() => _isUploading = true);
      try {
        final url = await ref
            .read(publicationServiceProvider)
            .uploadMedia(file.name, filePath: file.path, bytes: file.bytes);
        if (mounted) {
          setState(() {
            selectedCoverVideoFile = file;
            _coverVideoUrl = url;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vidéo de couverture uploadée ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur upload vidéo: $e'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur sélection vidéo : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  /// Upload le fichier sur le serveur et insère l'URL dans le Markdown du contenu.
  Future<void> _handleFileUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'webp',
          'mp4', 'avi', 'mov', 'mkv', 'webm',
          'pdf', 'txt',
        ],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      if (!mounted) return;
      setState(() => _isUploading = true);

      try {
        final service = ref.read(publicationServiceProvider);

        for (var file in result.files) {
          if ((file.bytes == null || file.bytes!.isEmpty) &&
              !kIsWeb &&
              file.path != null &&
              file.path!.isNotEmpty) {
            try {
              final readBytes = await File(file.path!).readAsBytes();
              file = PlatformFile(
                name: file.name,
                size: readBytes.length,
                bytes: readBytes,
                path: file.path,
              );
            } catch (_) {}
          }

          final fileName = file.name;
          final extension = fileName.split('.').last.toLowerCase();

          try {
            String contentToAdd = '';

            // Fichiers texte : lire les bytes directement
            if (extension == 'txt') {
              final textError = validateTextFile(file);
              if (textError != null) {
                _showMediaError(textError, fileName);
                continue;
              }
              String textContent = '';
              if (file.bytes != null) {
                textContent = String.fromCharCodes(file.bytes!);
              }
              contentToAdd = '$textContent---';
              if (mounted) {
                setState(() {
                  contentController.text =
                      contentController.text + contentToAdd;
                });
              }
              continue;
            }

            // Upload sur le serveur
            String url = await service.uploadMedia(
              fileName,
              filePath: file.path,
              bytes: file.bytes,
            );

            if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
              final imageError = validateContentImage(file);
              if (imageError != null) {
                _showMediaError(imageError, fileName);
                continue;
              }
              contentToAdd = '![]($url)\n\n';
            } else if (['mp4', 'avi', 'mov', 'mkv', 'webm']
                .contains(extension)) {
              final sizeError = validateContentVideoSize(file);
              if (sizeError != null) {
                _showMediaError(sizeError, fileName);
                continue;
              }
              contentToAdd = '[]($url)\n\n';
            } else if (extension == 'pdf') {
              final pdfError = await validatePdf(file);
              if (pdfError != null) {
                _showMediaError(pdfError, fileName);
                continue;
              }
              contentToAdd = '[]($url)\n\n';
            } else {
              contentToAdd = '[]($url)\n\n';
            }

            if (mounted) {
              setState(() {
                final current = contentController.text;
                final separator = (current.isEmpty || current.endsWith('\n\n'))
                    ? ''
                    : (current.endsWith('\n') ? '\n' : '\n\n');
                contentController.text = '$current$separator$contentToAdd';
              });
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur "$fileName" : $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} fichier(s) ajouté(s)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMediaError(String message, String fileName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('« $fileName » : $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Aperçu de la publication avant publication
  void _showPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Titre
                Text(
                  titleController.text.isEmpty
                      ? '(Sans titre)'
                      : titleController.text,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Meta
                Row(
                  children: [
                    Chip(
                      label: Text(selectedType.toUpperCase()),
                      backgroundColor: Colors.blue.shade50,
                      labelStyle: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(categoryNameController.text.isEmpty
                          ? 'Sans catégorie'
                          : categoryNameController.text),
                      backgroundColor: Colors.orange.shade50,
                      labelStyle: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isFree ? Icons.lock_open : Icons.lock,
                      color: isFree ? Colors.green : Colors.orange,
                      size: 18,
                    ),
                  ],
                ),
                if (tagsController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: tagsController.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .map((t) => Chip(
                              label: Text('#$t'),
                              backgroundColor: Colors.grey.shade100,
                              labelStyle: const TextStyle(fontSize: 11),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                // Couverture
                if (selectedCoverImageFile != null &&
                    selectedCoverImageFile!.bytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      selectedCoverImageFile!.bytes!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Résumé
                if (summaryController.text.isNotEmpty) ...[
                  Text(
                    summaryController.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Divider(),
                const SizedBox(height: 8),
                // Contenu (Markdown basique)
                Text(
                  contentController.text.isEmpty
                      ? '(Aucun contenu rédigé)'
                      : contentController.text,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isFree
                              ? 'Cette publication sera accessible à tous.'
                              : 'Prix : ${priceController.text} FCFA',
                          style: TextStyle(color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(String status) async {
    if (!_formKey.currentState!.validate()) return;
    final categoryName = categoryNameController.text.trim();
    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez indiquer le nom de la catégorie.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (status == 'published' &&
        selectedType == 'article' &&
        contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Impossible de publier : un article doit contenir du texte. "
              "Rédigez le contenu (ou joignez des fichiers) avant de publier."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final data = <String, dynamic>{
      'title': titleController.text.trim(),
      'description': summaryController.text.trim(),
      'content': contentController.text.trim(),
      'category_name': categoryName,
      'pub_type': selectedType,
      'prix': isFree ? 0.0 : double.parse(priceController.text.trim()),
      'resell_price': null,
      'is_free': isFree,
      'is_subscriber_exclusive': isSubscriberExclusive,
      'status': status,
      'tags': tagsController.text.trim(),
    };

    dynamic payload;
    // Couverture : image locale ou URL
    if (selectedCoverImageFile != null &&
        _coverType == 'image' &&
        selectedCoverImageFile!.bytes != null) {
      final formDataMap = <String, dynamic>{
        ...data,
        'cover_image': MultipartFile.fromBytes(
          selectedCoverImageFile!.bytes!,
          filename: selectedCoverImageFile!.name,
        ),
        'video_url': '',
        'file_url': '',
      };
      payload = FormData.fromMap(formDataMap);
    } else {
      payload = {
        ...data,
        'cover_image': _coverType == 'image'
            ? coverUrlController.text.trim()
            : '',
        'video_url': _coverType == 'video' ? _coverVideoUrl : '',
        'file_url': '',
      };
    }

    try {
      await ref
          .read(publisherPublicationsListProvider.notifier)
          .createPublication(payload);
      if (!mounted) return;
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
    } catch (e) {
      if (mounted) {
        final msg = e is Failure
            ? e.message
            : e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $msg'), backgroundColor: Colors.red),
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
      appBar: AppBar(
        title: const Text('Créer un article'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Aperçu',
            onPressed: _showPreview,
            icon: const Icon(Icons.preview_rounded),
          ),
          IconButton(
            tooltip: 'Sauvegarder brouillon',
            onPressed: () => _submit('draft'),
            icon: const Icon(Icons.save_outlined),
          ),
          TextButton.icon(
            onPressed: () => _submit('published'),
            icon: const Icon(Icons.publish_rounded, color: Colors.white, size: 18),
            label: const Text('Publier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showPreview,
                  icon: const Icon(Icons.preview, size: 18),
                  label: const Text('Aperçu'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _submit('draft'),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Brouillon'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _submit('published'),
                  icon: const Icon(Icons.publish, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  label: const Text('Publier', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
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
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Titre
                    TextFormField(
                      controller: titleController,
                      decoration: _inputDecoration(
                          'Titre de la publication', Icons.title),
                      validator: (value) =>
                          value == null || value.isEmpty
                              ? 'Champ requis'
                              : null,
                    ),
                    const SizedBox(height: 14),

                    // ── Catégorie
                    categoriesAsync.when(
                      data: (catList) {
                        final existingNames = catList
                            .map((c) => c['name']?.toString() ?? '')
                            .where((n) => n.isNotEmpty)
                            .toSet()
                            .toList();
                        return Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return existingNames;
                            }
                            return existingNames.where((name) => name
                                .toLowerCase()
                                .contains(textEditingValue.text
                                    .toLowerCase()));
                          },
                          onSelected: (selection) {
                            categoryNameController.text = selection;
                          },
                          fieldViewBuilder: (context, controller,
                              focusNode, onSubmit) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: (value) {
                                categoryNameController.text = value;
                              },
                              decoration: _inputDecoration(
                                      'Catégorie', Icons.category)
                                  .copyWith(
                                helperText: existingNames.isEmpty
                                    ? 'Aucune catégorie existante : écrivez-en une nouvelle.'
                                    : 'Écrivez le nom de la catégorie (existante ou nouvelle).',
                                helperMaxLines: 2,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Champ requis'
                                      : null,
                            );
                          },
                          optionsViewBuilder:
                              (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius:
                                    BorderRadius.circular(12),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxHeight: 200),
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    children: options
                                        .map((name) => ListTile(
                                              title: Text(name),
                                              onTap: () =>
                                                  onSelected(name),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => TextFormField(
                        controller: categoryNameController,
                        decoration: _inputDecoration(
                                'Catégorie', Icons.category)
                            .copyWith(
                                helperText:
                                    'Chargement des catégories existantes...'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Champ requis'
                                : null,
                      ),
                      error: (e, __) => TextFormField(
                        controller: categoryNameController,
                        decoration: _inputDecoration(
                                'Catégorie', Icons.category)
                            .copyWith(
                                helperText:
                                    'Écrivez le nom de la catégorie.'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Champ requis'
                                : null,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Type de publication
                    DropdownButtonFormField<String>(                            initialValue: selectedType,
                      decoration: _inputDecoration(
                          'Type de publication',
                          Icons.layers_outlined),
                      items: const [
                        DropdownMenuItem(
                            value: 'article',
                            child: Text('Article')),
                        DropdownMenuItem(
                            value: 'magazine',
                            child: Text('Magazine')),
                        DropdownMenuItem(
                            value: 'journal',
                            child: Text('Journal')),
                        DropdownMenuItem(
                            value: 'report',
                            child: Text('Rapport')),
                        DropdownMenuItem(
                            value: 'ebook', child: Text('E-book')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedType = value);
                        }
                      },
                    ),
                          const SizedBox(height: 20),

                          // ── Couverture : Image OU Vidéo
                          Text(
                            'Couverture',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _coverType = 'image'),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _coverType == 'image'
                                            ? const Color(0xFF2C74B3)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_rounded,
                                              size: 16,
                                              color: _coverType == 'image'
                                                  ? Colors.white
                                                  : Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Image',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: _coverType == 'image'
                                                  ? Colors.white
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _coverType = 'video'),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _coverType == 'video'
                                            ? const Color(0xFFD95A00)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.videocam_rounded,
                                              size: 16,
                                              color: _coverType == 'video'
                                                  ? Colors.white
                                                  : Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Vidéo',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: _coverType == 'video'
                                                  ? Colors.white
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          if (_coverType == 'image') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: coverUrlController,
                                    decoration: _inputDecoration(
                                        "URL de l'image de couverture",
                                        Icons.image_outlined),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? (selectedCoverImageFile !=
                                                    null
                                                ? null
                                                : 'Champ requis')
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton.filledTonal(
                                  icon: const Icon(
                                      Icons.photo_library_outlined),
                                  tooltip:
                                      "Choisir une image depuis l'appareil",
                                  onPressed: _isUploading
                                      ? null
                                      : _pickCoverImage,
                                ),
                              ],
                            ),
                            if (selectedCoverImageFile != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Colors.green, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Image locale sélectionnée ✓',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // ⚠️ Image preview : toujours via bytes (évite le crash content://)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: selectedCoverImageFile!.bytes != null
                                    ? Image.memory(
                                        selectedCoverImageFile!.bytes!,
                                        height: 140,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : const SizedBox(
                                        height: 140,
                                        child: Center(
                                          child:
                                              Text('Aperçu non disponible'),
                                        ),
                                      ),
                              ),
                            ],
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color:
                                              selectedCoverVideoFile != null
                                                  ? Colors.green
                                                  : Colors.grey.shade400),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      selectedCoverVideoFile != null
                                          ? '✓ Vidéo de couverture sélectionnée'
                                          : 'Aucune vidéo de couverture sélectionnée',
                                      style: TextStyle(
                                        color:
                                            selectedCoverVideoFile != null
                                                ? Colors.green.shade800
                                                : Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton.filledTonal(
                                  icon:
                                      const Icon(Icons.videocam_outlined),
                                  tooltip:
                                      'Choisir une vidéo de couverture',
                                  onPressed: _isUploading
                                      ? null
                                      : _pickCoverVideo,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),

                          // ── Accès libre
                          SwitchListTile(
                            title: const Text('Accès libre'),
                            subtitle: const Text(
                                "Les lecteurs peuvent lire cet article sans achat à l'unité"),
                            value: isFree,
                            activeThumbColor: Colors.orange.shade700,
                            onChanged: (val) {
                              setState(() {
                                isFree = val;
                                if (val) priceController.text = '0';
                                if (val) isSubscriberExclusive = false;
                              });
                            },
                          ),

                          // ── Réservé aux abonnés
                          SwitchListTile(
                            title: const Text('Réservé aux abonnés'),
                            subtitle: const Text(
                                "Contenu exclusif visible uniquement par vos abonnés — non achetable à l'unité"),
                            value: isSubscriberExclusive,
                            activeThumbColor: Colors.orange.shade700,
                            onChanged: (val) {
                              setState(() {
                                isSubscriberExclusive = val;
                                if (val) isFree = false;
                              });
                            },
                          ),

                          if (!isFree) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: _inputDecoration(
                                  'Prix individuel (FCFA)',
                                  Icons.payments_outlined),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requis';
                                if (double.tryParse(v) == null) {
                                  return 'Nombre invalide';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 14),

                          // ── Tags
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

                          // ── Résumé
                          TextFormField(
                            controller: summaryController,
                            maxLines: 3,
                            decoration: _inputDecoration(
                                'Résumé court / Description',
                                Icons.short_text_rounded),
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? 'Champ requis'
                                    : null,
                          ),
                          const SizedBox(height: 14),

                          // ── Toolbar formatting Markdown
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: Colors.grey.shade300),
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
                                  onTap: () =>
                                      _insertFormatting('\n---\n'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Corps de l'article + bouton pièce jointe
                          Stack(
                            children: [
                              TextFormField(
                                controller: contentController,
                                minLines: 10,
                                maxLines: 20,
                                decoration: _inputDecoration(
                                  "Contenu complet de l'article (Markdown)",
                                  Icons.description,
                                ).copyWith(
                                  hintText:
                                      'Rédigez le contenu… Utilisez 📎 pour joindre images, PDF ou vidéos.',
                                  helperText:
                                      'Les fichiers joints sont uploadés sur le serveur et insérés en tant que liens Markdown.',
                                  helperMaxLines: 2,
                                  contentPadding:
                                      const EdgeInsets.fromLTRB(
                                          48, 16, 48, 16),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Champ requis'
                                        : null,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Tooltip(
                                  message:
                                      'Joindre image, PDF ou vidéo\n(uploadé sur le serveur)',
                                  child: IconButton(
                                    icon: _isUploading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2),
                                          )
                                        : const Icon(Icons.attach_file),
                                    onPressed: _isUploading
                                        ? null
                                        : _handleFileUpload,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

          // ── 2e enfant du Stack : overlay upload par-dessus tout
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Upload en cours…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
