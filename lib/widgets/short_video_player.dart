import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/utils/platform_helper.dart';

class ShortVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? title;

  const ShortVideoPlayer({
    super.key,
    required this.videoUrl,
    this.title,
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


  @override
  void initState() {
    super.initState();
    if (!_unsupportedPlatform) {
      _initializePlayer();
    }
  }

  void _initializePlayer() {
    final uri = Uri.parse(widget.videoUrl);
    _controller = VideoPlayerController.networkUrl(uri)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });

    _controller!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
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
        // Hide controls after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && ctrl.value.isPlaying) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
    });
  }

  void _toggleMute() {
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      ctrl.setVolume(ctrl.value.volume == 0 ? 1 : 0);
    });
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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              launchUrl(Uri.parse(widget.videoUrl), mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Ouvrir dans le navigateur'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C74B3),
              foregroundColor: Colors.white,
            ),
          ),
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
    final isMuted = ctrl.value.volume == 0;
    final isPlaying = ctrl.value.isPlaying;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
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

              // Title overlay (top)
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

              // Play/Pause big button center overlay
              if (_showControls)
                Center(
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
                    child: Column(
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
                              '${_printDuration(ctrl.value.position)} / ${_printDuration(ctrl.value.duration)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
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
                  ),
                ),
            ],
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
