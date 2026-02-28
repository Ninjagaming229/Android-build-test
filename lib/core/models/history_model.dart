// lib/core/models/history_model.dart

class HistoryItem {
  final String jobId;
  final String status;
  final String filePath;
  final String createdAt;
  final String errorMessage;
  final int secondsLeft;

  HistoryItem({
    required this.jobId,
    required this.status,
    required this.filePath,
    required this.createdAt,
    required this.errorMessage,
    required this.secondsLeft,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      jobId: json['job_id'] ?? '',
      status: json['status'] ?? 'unknown',
      filePath: json['file_path'] ?? '',
      createdAt: json['created_at'] ?? '',
      errorMessage: json['error_message'] ?? '',
      secondsLeft: json['seconds_left'] ?? 0,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing' || status == 'queued';
  bool get isExpired => secondsLeft <= 0 && isCompleted;
}
