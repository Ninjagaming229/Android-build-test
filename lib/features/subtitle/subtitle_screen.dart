// lib/features/subtitle/subtitle_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';

enum SubtitleStatus { idle, uploading, processing, done, error }

class SubtitleScreen extends StatefulWidget {
  const SubtitleScreen({super.key});

  @override
  State<SubtitleScreen> createState() => _SubtitleScreenState();
}

class _SubtitleScreenState extends State<SubtitleScreen> {
  final _api = ApiClient();

  File? _selectedVideo;
  SubtitleStatus _status = SubtitleStatus.idle;
  double _uploadProgress = 0;
  int _currentChunk = 0;
  int _totalChunks = 0;
  String? _jobId;
  String? _downloadUrl;
  String _statusMessage = '';
  Timer? _pollTimer;

  // Subtitle options
  String _fontColor = '#FFFFFF';
  String _boxColor = '#000000';
  int _fontSize = 16;
  bool _boxEnabled = true;
  double _boxOpacity = 0.5;
  String _position = 'bottom_center';

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────
  // Pick video file
  // ─────────────────────────────────
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedVideo = File(result.files.single.path!);
        _status = SubtitleStatus.idle;
        _uploadProgress = 0;
        _downloadUrl = null;
        _jobId = null;
      });
    }
  }

  // ─────────────────────────────────
  // Upload video in chunks
  // ─────────────────────────────────
  Future<String> _uploadVideo(File video) async {
    final bytes = await video.readAsBytes();
    final filename = video.path.split('/').last;
    final fileSize = bytes.length;
    final chunkSize = AppConstants.chunkSize;
    final totalChunks = (fileSize / chunkSize).ceil();

    setState(() {
      _totalChunks = totalChunks;
      _currentChunk = 0;
      _statusMessage = 'Upload session စတင်နေသည်...';
    });

    // Step 1: Init
    final uploadId = await _api.uploadInit(
      filename: filename,
      totalChunks: totalChunks,
      fileSize: fileSize,
    );

    // Step 2: Send chunks
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize).clamp(0, fileSize);
      final chunk = bytes.sublist(start, end);

      await _api.uploadChunk(uploadId: uploadId, chunkIndex: i, chunkBytes: chunk);

      setState(() {
        _currentChunk = i + 1;
        _uploadProgress = (i + 1) / totalChunks;
        _statusMessage = 'Upload: ${_currentChunk}/${_totalChunks} chunks';
      });
    }

    // Step 3: Complete
    setState(() => _statusMessage = 'Server မှ ပြင်ဆင်နေသည်...');
    final filename2 = await _api.uploadComplete(uploadId);
    return filename2;
  }

  // ─────────────────────────────────
  // Start full process
  // ─────────────────────────────────
  Future<void> _startProcess() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video file ရွေးပါ')),
      );
      return;
    }

    setState(() {
      _status = SubtitleStatus.uploading;
      _uploadProgress = 0;
      _statusMessage = 'Upload စတင်နေသည်...';
    });

    try {
      // 1. Upload
      final uploadedFilename = await _uploadVideo(_selectedVideo!);

      // 2. Process subtitles
      setState(() {
        _status = SubtitleStatus.processing;
        _statusMessage = 'Subtitle Processing Queue ထဲ သွင်းနေသည်...';
      });

      final res = await _api.processSubtitles(
        uploadedFilename: uploadedFilename,
        subtitleOptions: {
          'subtitle_font_color': _fontColor,
          'subtitle_font_size': _fontSize.toString(),
          'subtitle_box_enabled': _boxEnabled ? 'on' : 'off',
          'subtitle_box_color': _boxColor,
          'subtitle_box_opacity': _boxOpacity.toString(),
          'subtitle_position': _position,
          'bypass_flip': 'off',
          'bypass_noise': 'off',
          'blur_areas': '[]',
        },
      );

      if (res['status'] == 'queued') {
        _jobId = res['job_id'];
        setState(() => _statusMessage = 'Processing Queue ထဲ ရောက်ပြီ၊ စစ်ဆေးနေသည်...');
        _startPolling();
      } else {
        throw Exception(res['message'] ?? 'Processing မစနိုင်ပါ');
      }
    } catch (e) {
      setState(() {
        _status = SubtitleStatus.error;
        _statusMessage = 'Error: $e';
      });
    }
  }

  // ─────────────────────────────────
  // Poll job status every 3 seconds
  // ─────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(AppConstants.pollInterval, (_) async {
      if (_jobId == null) return;
      try {
        final data = await _api.getJobStatus(_jobId!);
        final jobStatus = data['status'];

        if (jobStatus == 'completed') {
          _pollTimer?.cancel();
          setState(() {
            _status = SubtitleStatus.done;
            _downloadUrl = _api.getDownloadUrl(data['url'] ?? '');
            _statusMessage = '✅ Processing ပြီးဆုံးပြီ!';
          });
        } else if (jobStatus == 'failed') {
          _pollTimer?.cancel();
          setState(() {
            _status = SubtitleStatus.error;
            _statusMessage = 'Failed: ${data['message'] ?? 'Unknown error'}';
          });
        } else {
          setState(() {
            _statusMessage = 'Processing ဆဲ... ($jobStatus)';
          });
        }
      } catch (_) {}
    });
  }

  void _reset() {
    _pollTimer?.cancel();
    setState(() {
      _selectedVideo = null;
      _status = SubtitleStatus.idle;
      _uploadProgress = 0;
      _jobId = null;
      _downloadUrl = null;
      _statusMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Subtitle ထည့်ရန်', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_status != SubtitleStatus.idle)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
              onPressed: _reset,
              tooltip: 'Reset',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video picker section
            _buildVideoPickerCard(),
            const SizedBox(height: 16),

            // Subtitle options (only show when idle/video selected)
            if (_status == SubtitleStatus.idle && _selectedVideo != null)
              _buildSubtitleOptions(),

            // Progress / Status section
            if (_status != SubtitleStatus.idle)
              _buildProgressSection(),

            // Done section
            if (_status == SubtitleStatus.done)
              _buildDoneSection(),

            const SizedBox(height: 24),

            // Start button
            if (_status == SubtitleStatus.idle)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _selectedVideo != null ? _startProcess : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text('Processing စတင်မည်', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPickerCard() {
    return GestureDetector(
      onTap: (_status == SubtitleStatus.idle) ? _pickVideo : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedVideo != null ? const Color(0xFF1E40AF) : const Color(0xFF334155),
            width: _selectedVideo != null ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _selectedVideo != null ? Icons.video_file : Icons.add_circle_outline,
              color: _selectedVideo != null ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
              size: 48,
            ),
            const SizedBox(height: 12),
            if (_selectedVideo != null) ...[
              Text(
                _selectedVideo!.path.split('/').last,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              FutureBuilder<int>(
                future: _selectedVideo!.length(),
                builder: (ctx, snap) => Text(
                  snap.hasData ? '${(snap.data! / 1024 / 1024).toStringAsFixed(1)} MB' : '',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              const Text('ပြောင်းလဲရန် တာ့ပါ', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12)),
            ] else ...[
              const Text('Video ရွေးရန် ဒီနေရာကို တာ့ပါ', style: TextStyle(color: Color(0xFF94A3B8))),
              const SizedBox(height: 4),
              const Text('MP4, MOV, AVI ပံ့ပိုးသည်', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subtitle Settings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Font size
          Row(
            children: [
              const Text('Font Size:', style: TextStyle(color: Color(0xFF94A3B8))),
              Expanded(
                child: Slider(
                  value: _fontSize.toDouble(),
                  min: 10,
                  max: 30,
                  divisions: 20,
                  activeColor: const Color(0xFF3B82F6),
                  label: _fontSize.toString(),
                  onChanged: (v) => setState(() => _fontSize = v.round()),
                ),
              ),
              Text('$_fontSize', style: const TextStyle(color: Colors.white)),
            ],
          ),

          // Position
          const Text('Position:', style: TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              'bottom_center', 'top_center', 'middle_center'
            ].map((pos) => ChoiceChip(
              label: Text(pos.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
              selected: _position == pos,
              onSelected: (_) => setState(() => _position = pos),
              selectedColor: const Color(0xFF1E40AF),
              backgroundColor: const Color(0xFF334155),
              labelStyle: TextStyle(color: _position == pos ? Colors.white : const Color(0xFF94A3B8)),
            )).toList(),
          ),
          const SizedBox(height: 12),

          // Box enabled toggle
          SwitchListTile(
            title: const Text('Background Box', style: TextStyle(color: Color(0xFF94A3B8))),
            value: _boxEnabled,
            activeColor: const Color(0xFF3B82F6),
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _boxEnabled = v),
          ),

          // Box opacity
          if (_boxEnabled) ...[
            Row(
              children: [
                const Text('Opacity:', style: TextStyle(color: Color(0xFF94A3B8))),
                Expanded(
                  child: Slider(
                    value: _boxOpacity,
                    min: 0,
                    max: 1,
                    divisions: 10,
                    activeColor: const Color(0xFF3B82F6),
                    label: _boxOpacity.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _boxOpacity = v),
                  ),
                ),
                Text(_boxOpacity.toStringAsFixed(1), style: const TextStyle(color: Colors.white)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          if (_status == SubtitleStatus.uploading) ...[
            const Text('📤 Video Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: const Color(0xFF334155),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_uploadProgress * 100).toStringAsFixed(0)}% — $_currentChunk/$_totalChunks chunks',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
          if (_status == SubtitleStatus.processing) ...[
            const CircularProgressIndicator(color: Color(0xFF3B82F6)),
            const SizedBox(height: 12),
            const Text('⚙️ Subtitle Processing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
          if (_status == SubtitleStatus.error) ...[
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: TextStyle(
              color: _status == SubtitleStatus.error ? Colors.red : const Color(0xFF94A3B8),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDoneSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF059669)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          const Text('Video ပြီးဆုံးပြီ! 🎉', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showDownloadDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text('Download Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _reset,
            child: const Text('ထပ်မံ Process မည်', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Download Link', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ဒီ URL ကို browser မှာ ဖွင့်ပြီး download ဆွဲပါ:', style: TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 8),
            SelectableText(
              _downloadUrl ?? '',
              style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
