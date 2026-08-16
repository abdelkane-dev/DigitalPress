import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../core/utils/platform_helper.dart';

class ShortVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? title;

  /// Vidéo de couverture : se joue automatiquement UNE seule fois à
  /// l'ouverture, puis la lecture repasse entièrement sous le contrôle de
  /// l'utilisateur (aucune boucle automatique).
  final bool autoPlayOnce;

  const ShortVideoPlayer({
    super.key,
    required this.videoUrl,
    this.title,
    this.autoPlayOnce = false,
  });

  @override
  State<ShortVideoPlayer> createState() => _ShortVideoPlayerState();
}

class _ShortVideoPlayerState extends State<ShortVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;

  /// Vrai si la plateforme ne supporte pas video_player.
  bool get _unsupportedPlatform => !PlatformHelper.supportsVideoPlayer;

  // ─── CACHE DE LECTEURS PAR URL ─────────────────────────────────────────
  // Le fil d'accueil recrée les cartes à chaque scroll : sans cache, chaque
  // retour de carte re-téléchargeait intégralement la vidéo de couverture
  // (ex: 31 Mo re-téléchargés ~20 fois en quelques minutes — visible en
  // lecture saccadée / image de mauvaise qualité pendant le buffering).
  // On réutilise le controller initialisé au lieu de tout re-télécharger.
  static final Map<String, VideoPlayerController> _controllerCache = {};

  /// Nombre maximum de lecteurs gardés en mémoire : borne l'empreinte
  /// (chaque vidéo garde son buffer décodé). Les plus anciens sont disposés.
  static const int _cacheMaxSize = 4;

  static void _storeInCache(String url, VideoPlayerController controller) {
    _controllerCache[url] = controller;
    // Éviction des plus anciens (l'ordre d'insertion de la Map = l'ordre
    // d'ancienneté) pour ne jamais dépasser le plafond mémoire.
    while (_controllerCache.length > _cacheMaxSize) {
      _controllerCache.remove(_controllerCache.keys.first)?.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    if (!_unsupportedPlatform) {
      _initializePlayer();
    }
  }

  void _initializePlayer() {
    final url = widget.videoUrl;

    // Réutilise un lecteur déjà initialisé pour cette URL (retour de carte
    // dans le fil) : la vidéo est déjà en mémoire, plus de re-téléchargement.
    final cached = _controllerCache[url];
    if (cached != null) {
      _controller = cached;
      cached.initialize().then((_) {
        if (!mounted) return;
        setState(() => _isInitialized = true);
        _setupAutoPreview();
      }).catchError((error) {
        if (mounted) setState(() => _hasError = true);
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    // Mis en cache IMMÉDIATEMENT (avant la fin de l'initialisation) : si la
    // carte disparaît puis revient pendant le chargement, le nouveau widget
    // adopte ce même controller au lieu d'en lancer un second.
    _controller = controller;
    _storeInCache(url, controller);
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isInitialized = true);
      _setupAutoPreview();
    }).catchError((error) {
      // Un lecteur en échec ne doit pas rester dans le cache.
      if (_controllerCache[url] == controller) {
        _controllerCache.remove(url);
      }
      if (mounted) setState(() => _hasError = true);
    });
  }

  /// Auto-play unique pour les vidéos de couverture : la vidéo démarre
  /// toute seule, EN SILENCE (volume 0), une fois, et s'arrête après
  /// quelques secondes (demande explicite : « en silence, pas de musique et
  /// juste quelques secondes »). Aucune boucle, et le son reste coupé tant
  /// que l'utilisateur n'appuie pas sur le bouton.
  void _setupAutoPreview() {
    if (widget.autoPlayOnce) {
      _controller?.setVolume(0);
      _controller?.play();
      _controller?.addListener(_stopAfterShortPreview);
    }
  }

  /// Durée maximale de l'aperçu automatique d'une couverture vidéo :
  /// quelques secondes suffisent (demande explicite), pas la vidéo entière.
  static const _previewMaxDuration = Duration(seconds: 3);

  /// Interrompt la lecture automatique dès que l'aperçu de couverture a duré
  /// [_previewMaxDuration] (ou si la vidéo se termine avant). Après ça,
  /// c'est l'utilisateur qui reprend la main avec le bouton lecture.
  void _stopAfterShortPreview() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final position = ctrl.value.position;
    final reachedLimit = position >= _previewMaxDuration;
    final ended = ctrl.value.duration > Duration.zero &&
        position >= ctrl.value.duration;
    if (ctrl.value.isPlaying && (reachedLimit || ended)) {
      ctrl.removeListener(_stopAfterShortPreview);
      ctrl.pause();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_stopAfterShortPreview);
    // Le controller n'est PAS disposé ici quand il appartient au cache : il
    // reste initialisé pour la prochaine apparition de la carte (c'est le
    // but du cache). L'éviction (taille max) le dispose le moment venu.
    super.dispose();
  }

  /// Pause / reprise de la vidéo. Aussi déclenchée par un TAP DIRECT sur la
  /// vidéo (demande explicite : « toucher la vidéo pour mettre en pause, puis
  /// toucher à nouveau pour reprendre ») — le simple tap remplace l'ancien
  /// comportement qui ne faisait qu'afficher/masquer les contrôles.
  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
      } else {
        ctrl.play();
        // Hide controls after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && ctrl.value.isPlaying) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
      // Les contrôles réapparaissent à chaque tap (pause/reprise) :
      // l'utilisateur garde toujours un retour visuel de l'action.
      _showControls = true;
    });
  }

  void _toggleMute() {
    final ctrl = _controller;
    if (ctrl == null) return;
    ctrl.setVolume(ctrl.value.volume == 0 ? 1.0 : 0.0);
  }

  /// Construit le widget de remplacement pour les plateformes
  /// qui ne supportent pas video_player (Windows, Linux).
  Widget _buildDesktopFallback() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_rounded, color: Color(0xFF2C74B3), size: 48),
          const SizedBox(height: 12),
          Text(
            widget.title ?? 'Vidéo',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'La lecture vidéo n\'est pas disponible sur cette plateforme.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          // Aucune option « ouvrir dans le navigateur » : rien ne doit
          // sortir de l'application (demande explicite anti-partage).
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fallback sur les plateformes sans video_player
    if (_unsupportedPlatform) {
      return _buildDesktopFallback();
    }

    if (_hasError) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
            SizedBox(height: 10),
            Text(
              'Impossible de charger la vidéo',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C74B3)),
          ),
        ),
      );
    }

    final ctrl = _controller!;

    return ExcludeSemantics(
      child: GestureDetector(
        // ─── PAUSE / REPRISE AU TAP (demande explicite) ──────────────────
        // Toucher la vidéo met en pause ; toucher à nouveau reprend la
        // lecture. Les contrôles (bouton central, barre de progression)
        // s'affichent en même temps pour un retour visuel clair.
        onTap: _togglePlay,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: ctrl.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                VideoPlayer(ctrl),

                // Title overlay (top) — placé AVANT le bouton plein écran
                // dans le Stack pour que le bouton reste au-dessus et
                // toujours cliquable (le fond dégradé du titre interceptait
                // les taps → « je clique sur plein écran mais rien ne se
                // passe »).
                if (widget.title != null && _showControls)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Text(
                        widget.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                // ─── PLEIN ÉCRAN (comme le PDF) ─────────────────────────
                // Bouton d'agrandissement : ouvre le lecteur plein écran en
                // mode paysage (la vidéo passe naturellement sur le côté).
                // On transmet le CONTROLLER existant au plein écran : la
                // lecture continue exactement là où elle en était, sans
                // re-télécharger la vidéo ni la mettre en pause (auparavant
                // un second lecteur était créé → « rien ne se passe » ou
                // « la vidéo se met en pause »).
                if (_showControls)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FullScreenVideoViewer(
                                controller: _controller,
                                videoUrl: widget.videoUrl,
                                title: widget.title,
                              ),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Play/Pause big button center overlay
                if (_showControls)
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: ctrl,
                    builder: (context, value, child) {
                      final isPlaying = value.isPlaying;
                      return Center(
                        child: FloatingActionButton(
                          heroTag: 'play_video_${widget.videoUrl.hashCode}',
                          backgroundColor: Colors.black45,
                          onPressed: _togglePlay,
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      );
                    },
                  ),

                // Controls bar (bottom)
                if (_showControls)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: ctrl,
                        builder: (context, value, child) {
                          final isMuted = value.volume == 0;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress slider
                              VideoProgressIndicator(
                                ctrl,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Color(0xFF2C74B3),
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_printDuration(value.position)} / ${_printDuration(value.duration)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: _toggleMute,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

/// Lecteur vidéo plein écran, en mode paysage (la vidéo passe sur le côté),
/// comme le mode plein écran du PDF. Le nom de fichier n'est jamais affiché :
/// seuls le titre de l'article ou un libellé générique apparaissent.
///
/// [controller] peut être le controller DÉJÀ utilisé par le lecteur inline :
/// la lecture continue alors sans coupure (pas de re-téléchargement, pas de
/// pause). S'il est null (ou pas encore initialisé), un nouveau lecteur est
/// créé à partir de [videoUrl].
class FullScreenVideoViewer extends StatefulWidget {
  final String videoUrl;
  final String? title;
  final VideoPlayerController? controller;

  const FullScreenVideoViewer({
    super.key,
    required this.videoUrl,
    this.title,
    this.controller,
  });

  @override
  State<FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  // Le champ n'est jamais réassigné (la visibilité des contrôles est
  // pilotée par le tap sur la vidéo qui bascule lecture/pause) : final.
  final bool _showControls = true;

  /// Vrai si ce widget a créé son propre controller (à disposer en sortie).
  /// Un controller partagé avec le lecteur inline appartient au widget
  /// d'origine : on ne le dispose jamais ici.
  bool _ownsController = false;

  /// Restaure l'orientation et l'UI système d'origine en quittant le plein
  /// écran (portrait + barres système visibles).
  Future<void> _restoreOrientation() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    // Vidéo plein écran → mode paysage ("la vidéo passe sur le côté").
    try {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}
    // Cacher les barres système pour un vrai plein écran immersif.
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}

    if (PlatformHelper.supportsVideoPlayer) {
      final shared = widget.controller;
      if (shared != null && shared.value.isInitialized) {
        // Controller partagé : la vidéo continue là où elle en était.
        _controller = shared;
        _isInitialized = true;
        if (!shared.value.isPlaying) shared.play();
      } else {
        _ownsController = true;
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
          ..initialize().then((_) {
            if (mounted) {
              setState(() => _isInitialized = true);
              _controller?.play();
            }
          }).catchError((error) {
            if (mounted) setState(() => _hasError = true);
          });
      }
    }
  }

  @override
  void dispose() {
    _restoreOrientation();
    if (_ownsController) {
      _controller?.dispose();
    }
    super.dispose();
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
      } else {
        ctrl.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    widget.title ?? 'Vidéo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: _hasError
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 44),
                          SizedBox(height: 10),
                          Text('Impossible de charger la vidéo',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    )
                  : !_isInitialized
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF2C74B3)),
                          ),
                        )
                      : GestureDetector(
                          // Même comportement que le lecteur inline : un tap
                          // met en pause / reprend la lecture (demande
                          // explicite) et réaffiche les contrôles.
                          onTap: _togglePlay,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio:
                                  _controller!.value.aspectRatio,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoPlayer(_controller!),
                                  if (_showControls)
                                    ValueListenableBuilder<
                                        VideoPlayerValue>(
                                      valueListenable: _controller!,
                                      builder: (context, value, child) {
                                        return Column(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            FloatingActionButton(
                                              heroTag: 'fs_play_${widget.videoUrl.hashCode}',
                                              backgroundColor:
                                                  Colors.black45,
                                              onPressed: _togglePlay,
                                              child: Icon(
                                                value.isPlaying
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 40,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: 280,
                                              child: VideoProgressIndicator(
                                                _controller!,
                                                allowScrubbing: true,
                                                colors:
                                                    const VideoProgressColors(
                                                  playedColor:
                                                      Color(0xFF2C74B3),
                                                  bufferedColor:
                                                      Colors.white24,
                                                  backgroundColor:
                                                      Colors.white12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
