import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/article/article_detail_provider.dart';
import '../utils/logger.dart';

class AudioPlayer extends ConsumerStatefulWidget {
  final String localPath; // 改为本地文件路径
  final VoidCallback onClose;
  final String? articleId;

  const AudioPlayer({
    Key? key,
    required this.localPath,
    required this.onClose,
    this.articleId,
  }) : super(key: key);

  @override
  ConsumerState<AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends ConsumerState<AudioPlayer> {
  late just_audio.AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isCompleted = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = just_audio.AudioPlayer();
    log.i('[AudioPlayer] 初始化播放器，本地文件: ${widget.localPath}');

    try {
      setState(() {
        _isLoading = true;
      });

      // 直接从本地文件加载，不需要网络请求
      log.i('[AudioPlayer] 从本地文件加载音频');
      final duration = await _audioPlayer.setFilePath(widget.localPath);
      log.i('[AudioPlayer] 本地音频加载完成，时长: $duration');

      if (duration != null) {
        setState(() {
          _duration = duration;
        });
      }

      _durationSubscription = _audioPlayer.durationStream.listen((duration) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      });

      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        setState(() {
          _position = position;
        });
      });

      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        log.d('[AudioPlayer] 播放器状态变化: playing=${state.playing}, processingState=${state.processingState}');
        setState(() {
          _isPlaying = state.playing;

          if (state.processingState == just_audio.ProcessingState.completed) {
            _isPlaying = false;
            _isCompleted = true;
            log.i('[AudioPlayer] 播放完成，暂停播放器');
            _audioPlayer.pause();
          }
        });
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      log.e('[AudioPlayer] 音频加载失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('音频加载失败: $e')));
      }
    }
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // 从ConsumerRef获取主题状态
    bool isDarkMode = false;
    if (widget.articleId != null) {
      isDarkMode = ref.watch(articleDetailProvider(widget.articleId!)
          .select((state) => state.isDarkMode));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.audiotrack,
                  color: isDarkMode ? Colors.white70 : const Color(0xFF6b4bbd)),
              const SizedBox(width: 12),
              Text(
                '收听音频',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        isDarkMode ? Colors.white70 : const Color(0xFF6b4bbd)),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                  color: isDarkMode ? Colors.white70 : const Color(0xFF6b4bbd),
                  iconSize: 36,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    if (_isPlaying) {
                      log.i('[AudioPlayer] 用户点击暂停');
                      _audioPlayer.pause();
                    } else {
                      if (_isCompleted) {
                        log.i('[AudioPlayer] 播放已完成，seek回起点重新播放');
                        await _audioPlayer.seek(Duration.zero);
                        _isCompleted = false;
                      }
                      log.i('[AudioPlayer] 用户点击播放');
                      _audioPlayer.play();
                    }
                  },
                ),
              const SizedBox(width: 12),
              // 添加关闭按钮
              IconButton(
                icon: Icon(Icons.close),
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    activeTrackColor: isDarkMode
                        ? Colors.white70
                        : const Color(0xFF6b4bbd),
                    inactiveTrackColor:
                        isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    thumbColor:
                        isDarkMode ? Colors.white : const Color(0xFF6b4bbd),
                    overlayColor: (isDarkMode
                            ? Colors.white
                            : const Color(0xFF6b4bbd))
                        .withOpacity(0.2),
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inMilliseconds.toDouble() == 0
                        ? 1
                        : _duration.inMilliseconds.toDouble(),
                    value: _position.inMilliseconds.toDouble().clamp(
                          0,
                          _duration.inMilliseconds.toDouble() == 0
                              ? 1
                              : _duration.inMilliseconds.toDouble(),
                        ),
                    onChanged: (value) {
                      log.i('[AudioPlayer] 用户拖动进度条 seek 到: ${Duration(milliseconds: value.toInt())}');
                      _audioPlayer.seek(
                        Duration(milliseconds: value.toInt()),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_duration),
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
