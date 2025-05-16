import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AssistantService {
  final String apiKey = dotenv.env['OPENAI_API_KEY']!;
  final String model = 'gpt-4o-mini'; // نموذج سريع، ممكن تغيره

  // تعليمات المساعد المعدلة
  final String systemPrompt = '''
أنت مساعد صوتي ذكي.
- إذا قال المستخدم: "اريد تشغيل خاصية القراءة" أو "اريد القراءة" أو "اريد تصوير النص" أو "افتح الكاميرا" أو أي نص له علاقة بهذه الكلمات — رد دائمًا بـ "تم التنفيذ".
- إذا قال المستخدم: "افتح الملف الشخصي" أو "عرض الملف" أو "اذهب للملف الشخصي" أو أي نص يتعلق بالملف الشخصي — رد دائمًا بـ "0".
- إذا قال المستخدم: "اذهب للرئيسية" أو "افتح الصفحة الرئيسية" أو "الرئيسية" أو أي نص يتعلق بالصفحة الرئيسية — رد دائمًا بـ "1".
- إذا قال المستخدم: "افتح الإعدادات" أو "غير الإعدادات" أو "الإعدادات" أو أي نص يتعلق بالإعدادات — رد دائمًا بـ "2".
- إذا أعطى المستخدم أي أمر آخر غير هذه الأوامر، رد دائمًا بـ "اعد الكلام".
''';

  // ميثود لإرسال رسالة واستقبال رد كـ String كامل
  Future<String> sendMessageToAssistant(String userMessage) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    try {
      // إنشاء قائمة مؤقتة تحتوي على الـ system prompt والرسالة الحالية
      final List<Map<String, String>> messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userMessage},
      ];

      // إرسال الطلب
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: headers,
        body: json.encode({
          'model': model,
          'messages': messages,
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
}