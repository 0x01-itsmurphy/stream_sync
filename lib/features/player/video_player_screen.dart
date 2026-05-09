import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  final FocusNode _focusNode = FocusNode();

  bool _showControls = true;
  bool _isBuffering = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    // Configure mpv for maximum compatibility (especially on TV hardware)
    player = Player(
      configuration: PlayerConfiguration(
        bufferSize: AppConstants.playerBufferSize,
      ),
    );

    final nativePlayer = player.platform as NativePlayer;
    nativePlayer.setProperty('hwdec', 'no');
    nativePlayer.setProperty('vo', 'gpu');
    nativePlayer.setProperty('demuxer-max-bytes', AppConstants.demuxerMaxBytes);
    nativePlayer.setProperty('demuxer-max-back-bytes', AppConstants.demuxerMaxBackBytes);
    nativePlayer.setProperty('cache', 'yes');

    controller = VideoController(player);

    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    player.open(Media(widget.streamUrl));

    // Listen to streams
    player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    // Auto-hide controls after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    player.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _seekRelative(int seconds) {
    final newPos = _position + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > _duration ? _duration : newPos);
    player.seek(clamped);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // D-pad Center / Enter / Select → Play/Pause
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      player.playOrPause();
      if (!_showControls) setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    // D-pad Left → Rewind 10s
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      _seekRelative(-10);
      if (!_showControls) setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    // D-pad Right → Forward 10s
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      _seekRelative(10);
      if (!_showControls) setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    // D-pad Up → Show controls
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      setState(() => _showControls = !_showControls);
      return KeyEventResult.handled;
    }

    // Back → Exit player
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    // Space bar → Play/Pause (for physical keyboards on TV boxes)
    if (key == LogicalKeyboardKey.space) {
      player.playOrPause();
      if (!_showControls) setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              // Video
              Positioned.fill(
                child: Video(controller: controller),
              ),

              // Buffering indicator
              if (_isBuffering)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),

              // Controls overlay
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black87,
                        ],
                        stops: [0.0, 0.2, 0.7, 1.0],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Top bar
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Center playback controls
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Rewind 10s
                            IconButton(
                              iconSize: 40,
                              icon: const Icon(Icons.replay_10, color: Colors.white),
                              onPressed: () => _seekRelative(-10),
                            ),
                            const SizedBox(width: 32),
                            // Play / Pause
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                iconSize: 56,
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: AppColors.textPrimary,
                                ),
                                onPressed: () => player.playOrPause(),
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Forward 10s
                            IconButton(
                              iconSize: 40,
                              icon: const Icon(Icons.forward_10, color: Colors.white),
                              onPressed: () => _seekRelative(10),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Bottom seek bar + time
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7,
                                  ),
                                  activeTrackColor: AppColors.accent,
                                  inactiveTrackColor: AppColors.textPrimary.withValues(alpha: 0.24),
                                  thumbColor: AppColors.accent,
                                  overlayColor: AppColors.accent
                                      .withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: _duration.inMilliseconds > 0
                                      ? _position.inMilliseconds
                                          .toDouble()
                                          .clamp(
                                            0,
                                            _duration.inMilliseconds
                                                .toDouble(),
                                          )
                                      : 0,
                                  max: _duration.inMilliseconds > 0
                                      ? _duration.inMilliseconds.toDouble()
                                      : 1,
                                  onChanged: (v) {
                                    player.seek(
                                      Duration(milliseconds: v.toInt()),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppFormatters.formatDuration(_position),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      AppFormatters.formatDuration(_duration),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
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
            ],
          ),
        ),
      ),
    );
  }
}
