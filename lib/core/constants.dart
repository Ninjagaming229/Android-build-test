// lib/core/constants.dart
// ⚠️ BASE_URL ကို မင်းရဲ့ server address နဲ့ ပြောင်းပါ

class AppConstants {
  // TODO: ဒီနေရာမှာ မင်းရဲ့ server URL ထည့်ပါ
  // Example: 'https://yourname.hf.space' (HuggingFace)
  // Example: 'https://recapmaker.online'
  static const String baseUrl = 'https://recapmaker.online';

  // Chunk size: 3MB — backend expect လုပ်တဲ့ size
  static const int chunkSize = 3 * 1024 * 1024; // 3MB

  // Job status polling (ဘယ်နှစ်စက္ကန့်တိုင်း စစ်မလဲ)
  static const Duration pollInterval = Duration(seconds: 3);

  // App name
  static const String appName = 'Recap Maker';
}
