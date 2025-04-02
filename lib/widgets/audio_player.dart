import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'dart:async';

class AudioPlayer extends StatefulWidget {
  final String url;
  final VoidCallback? onClose;

  const AudioPlayer({super.key, required this.url, this.onClose});

  @override
  State<AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<AudioPlayer> {
  late just_audio.AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isBuffering = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _bufferedPositionSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = just_audio.AudioPlayer();

    try {
      setState(() {
        _isLoading = true;
      });

      // 配置音频源，启用流式播放
      final duration = await _audioPlayer.setUrl(
        widget.url,
        preload: false, // 不预先加载整个文件
      );

      if (duration != null) {
        setState(() {
          _duration = duration;
        });
      }

      // 监听缓冲位置
      _bufferedPositionSubscription =
          _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
        setState(() {
          _bufferedPosition = bufferedPosition;
        });
      });

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
        setState(() {
          _isPlaying = state.playing;
          // 检测是否正在缓冲
          _isBuffering =
              state.processingState == just_audio.ProcessingState.buffering;

          if (state.processingState == just_audio.ProcessingState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
            _audioPlayer.seek(Duration.zero);
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
      // 显示加载错误
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
    _bufferedPositionSubscription?.cancel();
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
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
              const Icon(Icons.audiotrack, color: Color(0xFF6b4bbd)),
              const SizedBox(width: 12),
              const Text(
                '收听音频',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isLoading || _isBuffering)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                  color: const Color(0xFF6b4bbd),
                  iconSize: 36,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (_isPlaying) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.play();
                    }
                  },
                ),
              const SizedBox(width: 12),
              // 添加关闭按钮
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.grey[700],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_formatDuration(_position)),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    // 缓冲进度条背景
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // 缓冲进度条
                    FractionallySizedBox(
                      widthFactor: _duration.inMilliseconds > 0
                          ? _bufferedPosition.inMilliseconds /
                              _duration.inMilliseconds
                          : 0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // 播放进度滑块
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        activeTrackColor: const Color(0xFF6b4bbd),
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: const Color(0xFF6b4bbd),
                        overlayColor: const Color(0xFF6b4bbd).withOpacity(0.2),
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
                          _audioPlayer.seek(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatDuration(_duration)),
            ],
          ),
        ],
      ),
    );
  }
}
