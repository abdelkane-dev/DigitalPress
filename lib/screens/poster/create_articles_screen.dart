import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
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
  final TextEditingController coverUrlController = TextEditingController(
    text:
        'https://images.unsplash.com/photo-1504711434969-e33886168f5c?auto=format&fit=crop&w=800&q=80',
  );

  // Couverture : Image OU Vidéo (pas les deux)
  String _coverType = 'image'; // 'image' ou 'video'
  PlatformFile? selectedCoverImageFile;
  PlatformFile? selectedCoverVideoFile;
  String _coverVideoUrl = '';

  final TextEditingController categoryNameController = TextEditingController();
  String selectedType = 'article';
  bool isFree = true;
  bool isSubscriberExclusive = false;
  bool _isUploading = false;

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

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: kIsWeb);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      // ─── VALIDATION COUVERTURE : la photo de couverture est légère
      // (normes presse publique) — on calcule sa taille et on refuse ce
      // qui dépasse, avec un message clair.
      final error = validateCoverImage(file);
      if (error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
        return;
      }
      setState(() {
        selectedCoverImageFile = file;
        // Jamais le nom du fichier : on affiche un aperçu + un libellé
        // générique. Au moment de la publication, c'est le fichier local
        // lui-même qui est envoyé (MultipartFile), pas cette valeur.
        coverUrlController.clear();
      });
    }
  }

  Future<void> _pickCoverVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: kIsWeb);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      // ─── VALIDATION COUVERTURE VIDÉO : un aperçu bref (quelques
      // secondes) — on calcule la durée et la taille, et on refuse ce qui
      // dépasse avec un message clair.
      final sizeError = validateCoverVideoSize(file);
      if (sizeError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sizeError), backgroundColor: Colors.red),
        );
        return;
      }
      final duration = await videoDuration(file);
      final durationError = validateCoverVideoDuration(duration);
      if (durationError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(durationError), backgroundColor: Colors.red),
        );
        return;
      }
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
          'pdf',
          'txt',
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

        // Fichiers texte : lire directement, pas besoin d'upload.
        // Le nom du fichier n'est JAMAIS inséré dans le contenu.
        if (extension == 'txt') {
          final textError = validateTextFile(file);
          if (textError != null) {
            _showMediaError(textError, fileName);
            continue;
          }
          try {
            String textContent = '';
            if (file.bytes != null) {
              textContent = String.fromCharCodes(file.bytes!);
            } else if (!kIsWeb && file.path != null) {
              textContent = '';
            }
            contentToAdd = '$textContent\n\n---\n\n';
          } catch (_) {
            contentToAdd = '';
          }
          setState(() {
            contentController.text = contentController.text + contentToAdd;
          });
          continue;
        }

        // Upload sur le serveur → obtenir URL absolue
        final String url;
        try {
          url = await service.uploadMedia(fileName, filePath: file.path, bytes: file.bytes);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur upload : $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          continue;
        }

        // ─── AUCUNE MENTION « image / vidéo / pdf » DANS LA PUBLICATION ──
        // Le nom brut du fichier n'apparaît JAMAIS, et AUCUN libellé de
        // type (« Image », « Vidéo », « Document PDF ») n'est non plus
        // inséré : seule l'URL nue (marqueur `[]()`) est ajoutée — le
        // lecteur rend le média (image pleine page, lecteur vidéo, PDF
        // intégré) sans aucun texte parasite, conformément à la demande.
        // La détection du type se fait par l'extension de l'URL.
        if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
          // ─── VALIDATION IMAGE DE CONTENU : plus lourde que la couverture
          final imageError = validateContentImage(file);
          if (imageError != null) {
            _showMediaError(imageError, fileName);
            continue;
          }
          contentToAdd = '![]($url)\n\n';
        } else if (['mp4', 'avi', 'mov', 'mkv', 'webm'].contains(extension)) {
          // ─── VALIDATION VIDÉO DE CONTENU : plus longue que la couverture
          // (jusqu'à quelques dizaines de minutes, pas plus).
          final sizeError = validateContentVideoSize(file);
          if (sizeError != null) {
            _showMediaError(sizeError, fileName);
            continue;
          }
          final duration = await videoDuration(file);
          final durationError = validateContentVideoDuration(duration);
          if (durationError != null) {
            _showMediaError(durationError, fileName);
            continue;
          }
          contentToAdd = '[]($url)\n\n';
        } else if (extension == 'pdf') {
          // ─── VALIDATION PDF : 50 pages maximum.
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

  /// Affiche l'erreur de validation d'un média avec le nom du fichier
  /// concerné (le nom brut reste visible UNIQUEMENT dans ce message
  /// d'erreur interne, jamais dans le contenu publié).
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

    // ─── MESSAGE D'ERREUR PRÉCIS À LA PUBLICATION ───────────────────────
    // Le backend refuse aussi cette situation (voir PublicationCreateSerializer
    // : « Un article publié doit contenir du texte ») — on la détecte en
    // amont pour afficher un message clair immédiat, au lieu d'une erreur
    // générique au moment du clic sur « Publier l'article ».
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
      // Un seul champ de prix dans l'interface : le prix de revente reste
      // géré côté backend (défini à null à la création).
      'resell_price': null,
      'is_free': isFree,
      'is_subscriber_exclusive': isSubscriberExclusive,
      'status': status,
      'tags': tagsController.text.trim(),
    };

    dynamic payload;
    // Couverture : image locale ou URL
    if (selectedCoverImageFile != null && _coverType == 'image') {
      final formDataMap = <String, dynamic>{
        ...data,
        'cover_image': selectedCoverImageFile!.bytes != null
            ? MultipartFile.fromBytes(
                selectedCoverImageFile!.bytes!,
                filename: selectedCoverImageFile!.name,
              )
            : await MultipartFile.fromFile(
                selectedCoverImageFile!.path!,
                filename: selectedCoverImageFile!.name,
              ),
        'video_url': '',
        'file_url': '',
      };
      payload = FormData.fromMap(formDataMap);
    } else {
      payload = {
        ...data,
        'cover_image': _coverType == 'image' ? coverUrlController.text.trim() : '',
        'video_url': _coverType == 'video' ? _coverVideoUrl : '',
        'file_url': '',
      };
    }

    try {
      await ref
          .read(publisherPublicationsListProvider.notifier)
          .createPublication(payload);
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
        final msg = e is Failure ? e.message : e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $msg'), backgroundColor: Colors.red),
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
                                .contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (selection) {
                            categoryNameController.text = selection;
                          },
                          fieldViewBuilder:
                              (context, controller, focusNode, onSubmit) {
                            // ─── CORRECTIF : la version précédente ajoutait
                            // un addListener à chaque rebuild du champ
                            // (liste de listeners qui grossit sans fin).
                            // La synchronisation se fait désormais via
                            // onChanged (pas de fuite) + onSelected (ci-dessus).
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
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? 'Champ requis'
                                  : null,
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(12),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    children: options
                                        .map((name) => ListTile(
                                              title: Text(name),
                                              onTap: () => onSelected(name),
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
                        decoration: _inputDecoration('Catégorie', Icons.category)
                            .copyWith(helperText: 'Chargement des catégories existantes...'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Champ requis' : null,
                      ),
                      error: (e, __) => TextFormField(
                        controller: categoryNameController,
                        decoration: _inputDecoration('Catégorie', Icons.category)
                            .copyWith(helperText: 'Écrivez le nom de la catégorie.'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Champ requis' : null,
                      ),
                    ),

                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: _inputDecoration(
                          'Type de publication', Icons.layers_outlined),
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

                    const SizedBox(height: 20),

                    // ── Couverture : Image OU Vidéo ──────────────────────────
                    Text(
                      'Couverture',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Toggle Image / Vidéo
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
                              onTap: () => setState(() => _coverType = 'image'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _coverType == 'image'
                                      ? const Color(0xFF2C74B3)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                              onTap: () => setState(() => _coverType = 'video'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _coverType == 'video'
                                      ? const Color(0xFFD95A00)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                  'URL de l\'image de couverture', Icons.image_outlined),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? (selectedCoverImageFile != null
                                          ? null
                                          : 'Champ requis')
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.photo_library_outlined),
                            tooltip: 'Choisir une image depuis l\'appareil',
                            onPressed: _pickCoverImage,
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: selectedCoverImageFile!.bytes != null
                              ? Image.memory(
                                  selectedCoverImageFile!.bytes!,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(selectedCoverImageFile!.path!),
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
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
                                    color: selectedCoverVideoFile != null
                                        ? Colors.green
                                        : Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                selectedCoverVideoFile != null
                                    ? '✓ Vidéo de couverture sélectionnée'
                                    : 'Aucune vidéo de couverture sélectionnée',
                                style: TextStyle(
                                  color: selectedCoverVideoFile != null
                                      ? Colors.green.shade800
                                      : Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.videocam_outlined),
                            tooltip: 'Choisir une vidéo de couverture',
                            onPressed: _pickCoverVideo,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),

                    SwitchListTile(
                      title: const Text('Accès libre'),
                      subtitle: const Text(
                          'Les lecteurs peuvent lire cet article sans achat à l\'unité'),
                      value: isFree,
                      activeThumbColor: Colors.orange.shade700,
                      onChanged: (val) {
                        setState(() {
                          isFree = val;
                          if (val) priceController.text = '0';
                          // Un contenu gratuit n'a pas de sens en même temps
                          // qu'exclusif abonnés (voir switch ci-dessous).
                          if (val) isSubscriberExclusive = false;
                        });
                      },
                    ),

                    // ─── AJOUT : contenu réservé aux abonnés du compte ────
                    // Différent du contenu payant à l'unité ci-dessus : ce
                    // contenu n'est JAMAIS achetable individuellement, seul
                    // un abonnement actif à ce compte éditeur y donne accès
                    // (voir Publication.is_accessible_by côté backend).
                    SwitchListTile(
                      title: const Text('Réservé aux abonnés'),
                      subtitle: const Text(
                          "Contenu exclusif visible uniquement par vos abonnés — non achetable à l'unité"),
                      value: isSubscriberExclusive,
                      activeThumbColor: Colors.orange.shade700,
                      onChanged: (val) {
                        setState(() {
                          isSubscriberExclusive = val;
                          if (val) {
                            isFree = false;
                          }
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

                    // Corps de l'article + bouton pièce jointe
                    Stack(
                      children: [
                        TextFormField(
                          controller: contentController,
                          minLines: 10,
                          maxLines: 20,
                          decoration: _inputDecoration(
                            'Contenu complet de l\'article (Markdown)',
                            Icons.description,
                          ).copyWith(
                            hintText:
                                'Rédigez le contenu… Utilisez 📎 pour joindre images, PDF ou vidéos.',
                            helperText:
                                'Les fichiers joints sont uploadés sur le serveur et insérés en tant que liens Markdown.',
                            helperMaxLines: 2,
                            contentPadding: const EdgeInsets.fromLTRB(48, 16, 48, 16),
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
                                'Joindre image, PDF ou vidéo\n(uploadé sur le serveur)',
                            child: IconButton(
                              icon: _isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.attach_file),
                              onPressed: _isUploading ? null : _handleFileUpload,
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
          // Overlay de chargement upload
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
