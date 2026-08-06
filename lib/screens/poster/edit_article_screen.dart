import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
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
  late TextEditingController resellPriceController;
  late TextEditingController tagsController;
  late TextEditingController coverUrlController;

  final TextEditingController categoryNameController = TextEditingController();
  late String selectedType;
  late bool isFree;

  // Couverture : Image OU Vidéo
  String _coverType = 'image'; // 'image' ou 'video'
  PlatformFile? selectedCoverImageFile;
  PlatformFile? selectedCoverVideoFile;
  late String _coverVideoUrl;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.publication.title);
    summaryController = TextEditingController(text: widget.publication.description);
    contentController = TextEditingController(text: widget.publication.content);
    priceController = TextEditingController(text: widget.publication.prix.toStringAsFixed(0));
    resellPriceController = TextEditingController(text: widget.publication.resellPrice?.toStringAsFixed(0) ?? '');
    tagsController = TextEditingController(text: widget.publication.tags.join(', '));
    coverUrlController = TextEditingController(text: widget.publication.coverImage);

    categoryNameController.text = widget.publication.categoryName ?? '';
    selectedType = widget.publication.pubType;
    isFree = widget.publication.isFree;

    // Déterminer si la publication a une vidéo de couverture
    if (widget.publication.videoUrl.isNotEmpty) {
      _coverType = 'video';
      _coverVideoUrl = widget.publication.videoUrl;
    } else {
      _coverType = 'image';
      _coverVideoUrl = '';
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    contentController.dispose();
    priceController.dispose();
    resellPriceController.dispose();
    tagsController.dispose();
    coverUrlController.dispose();
    categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: kIsWeb);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        selectedCoverImageFile = result.files.single;
        coverUrlController.text = result.files.single.name;
      });
    }
  }

  Future<void> _pickCoverVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: kIsWeb);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'webp',
          'mp4', 'avi', 'mov', 'mkv', 'webm',
          'pdf', 'txt',
        ],
        allowMultiple: true,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);
      final service = ref.read(publicationServiceProvider);

      for (final file in result.files) {
        final fileName = file.name;
        final extension = fileName.split('.').last.toLowerCase();

        String contentToAdd = '';

        if (extension == 'txt') {
          try {
            String textContent = '';
            if (file.bytes != null) {
               textContent = String.fromCharCodes(file.bytes!);
            } else if (!kIsWeb && file.path != null) {
               textContent = '📄 [$fileName] (Text content attached)';
            }
            contentToAdd = '$textContent\n\n---\n\n';
          } catch (_) {
            contentToAdd = '📄 [$fileName]\n\n---\n\n';
          }
          setState(() {
            contentController.text = contentController.text + contentToAdd;
          });
          continue;
        }

        final String url;
        try {
          url = await service.uploadMedia(fileName, filePath: file.path, bytes: file.bytes);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur upload $fileName: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          continue;
        }

        if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
          contentToAdd = '![$fileName]($url)\n\n';
        } else if (['mp4', 'avi', 'mov', 'mkv', 'webm'].contains(extension)) {
          contentToAdd = '🎬 [$fileName]($url)\n\n';
        } else if (extension == 'pdf') {
          contentToAdd = '📄 [$fileName]($url)\n\n';
        } else {
          contentToAdd = '[$fileName]($url)\n\n';
        }

        if (mounted) {
          setState(() {
            contentController.text = contentController.text + contentToAdd;
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.files.length} fichier(s) ajouté(s) ✓'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categoryName = categoryNameController.text.trim();
    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez indiquer le nom de la catégorie.'), backgroundColor: Colors.red),
      );
      return;
    }

    final payload = <String, dynamic>{
      'title': titleController.text.trim(),
      'description': summaryController.text.trim(),
      'content': contentController.text.trim(),
      'category_name': categoryName,
      'pub_type': selectedType,
      'prix': isFree ? 0.0 : double.parse(priceController.text.trim()),
      'resell_price': resellPriceController.text.trim().isNotEmpty ? double.parse(resellPriceController.text.trim()) : null,
      'is_free': isFree,
      'tags': tagsController.text.trim(),
      'cover_image': _coverType == 'image' ? coverUrlController.text.trim() : '',
      'video_url': _coverType == 'video' ? _coverVideoUrl : '',
      'file_url': '',
    };

    try {
      await ref
          .read(publisherPublicationsListProvider.notifier)
          .updatePublication(widget.publication.id, payload);
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Modifier article'), centerTitle: true),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12, offset: Offset(0, 4))],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleController,
                      readOnly: widget.publication.originalPublicationId != null,
                      decoration: _inputDecoration('Titre de la publication', Icons.title).copyWith(
                        filled: widget.publication.originalPublicationId != null,
                        fillColor: widget.publication.originalPublicationId != null ? Colors.grey.shade200 : const Color(0xFFF8FAFC),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 14),

                    categoriesAsync.when(
                      data: (catList) {
                        final existingNames = catList.map((c) => c['name']?.toString() ?? '').where((n) => n.isNotEmpty).toSet().toList();
                        return Autocomplete<String>(
                          initialValue: TextEditingValue(text: categoryNameController.text),
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return existingNames;
                            return existingNames.where((n) => n.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (s) => categoryNameController.text = s,
                          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                            controller.addListener(() => categoryNameController.text = controller.text);
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: _inputDecoration('Catégorie', Icons.category),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) => Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  children: options.map((name) => ListTile(title: Text(name), onTap: () => onSelected(name))).toList(),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      loading: () => TextFormField(controller: categoryNameController, decoration: _inputDecoration('Catégorie', Icons.category)),
                      error: (e, __) => TextFormField(controller: categoryNameController, decoration: _inputDecoration('Catégorie', Icons.category)),
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
                      onChanged: (value) { if (value != null) setState(() => selectedType = value); },
                    ),

                    const SizedBox(height: 20),

                    // ── Couverture : Image OU Vidéo ──────────────────────────
                    Text('Couverture', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _coverType = 'image'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _coverType == 'image' ? const Color(0xFF2C74B3) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.image_rounded, size: 16, color: _coverType == 'image' ? Colors.white : Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('Image', style: TextStyle(fontWeight: FontWeight.w600, color: _coverType == 'image' ? Colors.white : Colors.grey)),
                                ]),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _coverType = 'video'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _coverType == 'video' ? const Color(0xFFD95A00) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.videocam_rounded, size: 16, color: _coverType == 'video' ? Colors.white : Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('Vidéo', style: TextStyle(fontWeight: FontWeight.w600, color: _coverType == 'video' ? Colors.white : Colors.grey)),
                                ]),
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
                              readOnly: widget.publication.originalPublicationId != null,
                              decoration: _inputDecoration('URL de l\'image de couverture', Icons.image_outlined).copyWith(
                                filled: widget.publication.originalPublicationId != null,
                                fillColor: widget.publication.originalPublicationId != null ? Colors.grey.shade200 : const Color(0xFFF8FAFC),
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (widget.publication.originalPublicationId == null)
                            IconButton.filledTonal(icon: const Icon(Icons.photo_library_outlined), tooltip: 'Choisir une image', onPressed: _pickCoverImage),
                        ],
                      ),
                      if (selectedCoverImageFile != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10), 
                          child: selectedCoverImageFile!.bytes != null
                              ? Image.memory(selectedCoverImageFile!.bytes!, height: 120, width: double.infinity, fit: BoxFit.cover)
                              : Image.file(File(selectedCoverImageFile!.path!), height: 120, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ],
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: _coverVideoUrl.isNotEmpty ? Colors.green : Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _coverVideoUrl.isNotEmpty ? '✓ Vidéo de couverture définie' : 'Aucune vidéo de couverture',
                                style: TextStyle(color: _coverVideoUrl.isNotEmpty ? Colors.green.shade800 : Colors.grey.shade600, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(icon: const Icon(Icons.videocam_outlined), tooltip: 'Choisir une vidéo de couverture', onPressed: _pickCoverVideo),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),

                    SwitchListTile(
                      title: const Text('Contenu Gratuit'),
                      subtitle: const Text('Les lecteurs peuvent lire cet article sans payer'),
                      value: isFree,
                      activeThumbColor: Colors.orange.shade700,
                      onChanged: (val) { setState(() { isFree = val; if (val) priceController.text = '0'; }); },
                    ),

                    if (!isFree) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _inputDecoration('Prix individuel (FCFA)', Icons.payments_outlined),
                              validator: (v) { if (v == null || v.isEmpty) return 'Requis'; if (double.tryParse(v) == null) return 'Nombre invalide'; return null; },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: resellPriceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _inputDecoration('Prix droit de revente', Icons.handshake_outlined).copyWith(
                                helperText: 'Optionnel',
                              ),
                              validator: (v) {
                                if (v != null && v.isNotEmpty && double.tryParse(v) == null) return 'Invalide';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),
                    TextFormField(controller: tagsController, decoration: _inputDecoration('Tags (séparés par des virgules)', Icons.local_offer_outlined)),

                    const SizedBox(height: 14),
                    TextFormField(
                      controller: summaryController,
                      maxLines: 3,
                      readOnly: widget.publication.originalPublicationId != null,
                      decoration: _inputDecoration('Résumé court / Description', Icons.short_text_rounded).copyWith(
                        filled: widget.publication.originalPublicationId != null,
                        fillColor: widget.publication.originalPublicationId != null ? Colors.grey.shade200 : const Color(0xFFF8FAFC),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 14),

                    // Toolbar + contenu avec bouton pièce jointe
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade300)),
                      child: Wrap(
                        spacing: 4,
                        children: [
                          _buildToolbarButton(icon: Icons.title, tooltip: 'Titre', onTap: () => _insertFormatting('# ')),
                          _buildToolbarButton(icon: Icons.subtitles, tooltip: 'Sous-titre', onTap: () => _insertFormatting('## ')),
                          _buildToolbarButton(icon: Icons.format_list_bulleted, tooltip: 'Liste', onTap: () => _insertFormatting('- ')),
                          _buildToolbarButton(icon: Icons.format_quote, tooltip: 'Citation', onTap: () => _insertFormatting('> ')),
                          _buildToolbarButton(icon: Icons.horizontal_rule, tooltip: 'Séparateur', onTap: () => _insertFormatting('\n---\n')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Stack(
                      children: [
                        TextFormField(
                          controller: contentController,
                          minLines: 10,
                          maxLines: 20,
                          readOnly: widget.publication.originalPublicationId != null,
                          decoration: _inputDecoration('Contenu complet de l\'article (Markdown)', Icons.description).copyWith(
                            hintText: 'Rédigez le contenu… Utilisez 📎 pour joindre images, PDF ou vidéos.',
                            helperText: 'Les fichiers joints sont uploadés sur le serveur et insérés en tant que liens Markdown.',
                            helperMaxLines: 2,
                            contentPadding: const EdgeInsets.fromLTRB(48, 16, 48, 16),
                            filled: widget.publication.originalPublicationId != null,
                            fillColor: widget.publication.originalPublicationId != null ? Colors.grey.shade200 : const Color(0xFFF8FAFC),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                        ),
                        if (widget.publication.originalPublicationId == null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Tooltip(
                            message: 'Joindre image, PDF ou vidéo\n(uploadé sur le serveur)',
                            child: IconButton(
                              icon: _isUploading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.attach_file),
                              onPressed: _isUploading ? null : _handleFileUpload,
                            ),
                          ),
                        ),
                      ],
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
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Upload en cours…'),
                      ]),
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