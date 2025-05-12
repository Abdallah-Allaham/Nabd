import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AssistantService {
  final String apiKey = dotenv.env['OPENAI_API_KEY']!;
  final String model = 'gpt-4o-mini'; // نموذج سريع، ممكن تغيره
  final List<Map<String, String>> _conversationHistory = [];

  // تعليمات المساعد
  final String systemPrompt = '''
أنت مساعد صوتي ذكي.
إذا قال المستخدم: "اريد تشغيل خاصية القراءة" أو "اريد القراءة" أو "اريد تصوير النص" أو "افتح الكاميرا" — رد عليه دائمًا بـ "تم التنفيذ".
إذا أعطى المستخدم أي أمر آخر غير هذه الأوامر، رد عليه بـ "اعد الكلام".
''';

  // ميثود لإرسال رسالة واستقبال رد كـ String كامل
  Future<String> sendMessageToAssistant(String userMessage) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    try {
      // إضافة تعليمات النظام والرسالة للتاريخ
      if (_conversationHistory.isEmpty) {
        _conversationHistory.add({'role': 'system', 'content': systemPrompt});
      }
      _conversationHistory.add({'role': 'user', 'content': userMessage});

      // إرسال الطلب
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: headers,
        body: json.encode({
          'model': model,
          'messages': _conversationHistory,
          'stream': false, // بدون Streaming
        }),
      );

      if (response.statusCode != 200) {
        print("📩 فشل إرسال الرسالة: ${response.body}");
        throw Exception('فشل إرسال الرسالة: ${response.statusCode}');
      }

      // فك التشفير واستخراج النص
      final data = json.decode(utf8.decode(response.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'];
      if (content == null) {
        throw Exception('لم يتم العثور على رد من المساعد.');
      }

      // تنظيف النص
      final cleanedText = cleanResponse(content);
      print("النص بعد التنظيف: $cleanedText");

      // إضافة رد المساعد للتاريخ
      _conversationHistory.add({'role': 'assistant', 'content': cleanedText});

      return cleanedText;
    } catch (e) {
      print("🚨 خطأ في AssistantService: $e");
      return "حدث خطأ";
    }
  }

  // ميثود لتنظيف الرد
  String cleanResponse(String text) {
    return text
        .replaceAll(RegExp(r' '), ' ')
        .replaceAll(RegExp(r'&#x[0-9a-fA-F]+;'), '');
  }

  // ميثود لمسح التاريخ
  void clearConversationHistory() {
    _conversationHistory.clear();
  }
}