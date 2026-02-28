// lib/core/api_client.dart
// Cookie-based session management — Login ပြီးရင် session auto-keep

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final CookieJar cookieJar = CookieJar();

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10), // video upload အတွက် ကြာနိုင်
      sendTimeout: const Duration(minutes: 10),
    ));

    // Session cookie auto-management
    dio.interceptors.add(CookieManager(cookieJar));

    // Debug logging (development မှာ)
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: true,
      error: true,
    ));
  }

  // ─────────────────────────────────────
  // AUTH
  // ─────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await dio.post(
        '/login',
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      return {'status': 'error', 'message': e.message ?? 'Connection failed'};
    }
  }

  Future<void> logout() async {
    try {
      await dio.get('/logout');
    } catch (_) {}
    await cookieJar.deleteAll();
  }

  // ─────────────────────────────────────
  // DASHBOARD
  // ─────────────────────────────────────

  Future<List<dynamic>> getHistory() async {
    final res = await dio.get('/api/my_history');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    final res = await dio.get('/status/$jobId');
    return res.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────
  // UPLOAD — Step 1: Init session
  // backend expect: JSON {filename, total_chunks, file_size}
  // backend returns: {status, upload_id}
  // ─────────────────────────────────────

  Future<String> uploadInit({
    required String filename,
    required int totalChunks,
    required int fileSize,
  }) async {
    final res = await dio.post(
      '/upload-init',
      data: {
        'filename': filename,
        'total_chunks': totalChunks,
        'file_size': fileSize,
      },
    );
    if (res.data['status'] != 'success') {
      throw Exception(res.data['message'] ?? 'Upload init failed');
    }
    return res.data['upload_id'] as String;
  }

  // ─────────────────────────────────────
  // UPLOAD — Step 2: Send each chunk
  // backend expect: FormData {upload_id, chunk_index, chunk(file)}
  // ─────────────────────────────────────

  Future<void> uploadChunk({
    required String uploadId,
    required int chunkIndex,
    required List<int> chunkBytes,
  }) async {
    final formData = FormData.fromMap({
      'upload_id': uploadId,
      'chunk_index': chunkIndex.toString(),
      'chunk': MultipartFile.fromBytes(chunkBytes, filename: 'chunk_$chunkIndex'),
    });
    await dio.post('/upload-chunk', data: formData);
  }

  // ─────────────────────────────────────
  // UPLOAD — Step 3: Complete
  // backend returns: {status, filename, path}
  // ─────────────────────────────────────

  Future<String> uploadComplete(String uploadId) async {
    final res = await dio.post(
      '/upload-complete',
      data: {'upload_id': uploadId},
    );
    if (res.data['status'] != 'success') {
      throw Exception(res.data['message'] ?? 'Upload complete failed');
    }
    return res.data['filename'] as String; // sanitized filename
  }

  // ─────────────────────────────────────
  // PROCESS SUBTITLES
  // backend expect: form data with video filename + subtitle options
  // backend returns: {status:'queued', job_id, new_balance, free_left}
  // ─────────────────────────────────────

  Future<Map<String, dynamic>> processSubtitles({
    required String uploadedFilename,
    required Map<String, String> subtitleOptions,
  }) async {
    final data = {
      'video_source': 'uploaded',
      'uploaded_video_filename': uploadedFilename,
      ...subtitleOptions,
    };

    final res = await dio.post(
      '/process-subtitles',
      data: data,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return res.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────
  // Download URL builder
  // ─────────────────────────────────────

  String getDownloadUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${AppConstants.baseUrl}$url';
  }
}
