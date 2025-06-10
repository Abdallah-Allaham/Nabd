import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AssistantService {
  final String apiKey = dotenv.env['OPENAI_API_KEY']!;
  final String model = 'gpt-4o-mini'; // نموذج سريع

  final String systemPrompt = '''
أنت مساعد صوتي ذكي مهمتك هي فهم الأوامر الصوتية للمستخدم وتحديد الوظيفة المطلوبة بدقة متناهية. يجب أن يكون ردك حصراً أحد القيم التالية: "تم التنفيذ", "0", "1", "2", "اعد الكلام". لا تقم بإضافة أي نصوص إضافية أو شروحات.

- إذا طلب المستخدم "اريد تشغيل خاصية القراءة" أو "اريد القراءة" أو "اريد تصوير النص" أو "افتح الكاميرا" أو "كاميرا" أو "صور" أو "ابدأ التصوير" أو أي عبارة تدل على فتح الكاميرا أو القراءة: رد بـ "تم التنفيذ".
- إذا طلب المستخدم "افتح الملف الشخصي" أو "عرض الملف" أو "اذهب للملف الشخصي" أو "profile" أو "ملف" أو "صفحة ملفي" أو "شوف بياناتي" أو أي عبارة تدل على الملف الشخصي: رد بـ "0".
- إذا طلب المستخدم "اذهب للرئيسية" أو "افتح الصفحة الرئيسية" أو "الرئيسية" أو "home" أو "هوم" أو "عودة للرئيسية" أو "الصفحة الرئيسية" أو "افتح الرئيسية": رد بـ "1".
- إذا طلب المستخدم "افتح الإعدادات" أو "اعدادات" أو "غير الإعدادات" أو "الإعدادات" أو "setting" أو "صفحة الإعدادات" أو "خيارات التطبيق": رد بـ "2".
- إذا أعطى المستخدم أي أمر آخر غير الأوامر المذكورة أعلاه، أو كان الأمر غير واضح أو لم تفهمه تمامًا: رد دائمًا بـ "اعد الكلام".
حافظ على الردود موجزة ومباشرة، بدون أي إضافات.
''';

  // ميثود لإرسال رسالة واستقبال رد كـ String كامل
  Future<String> sendMessageToAssistant(String userMessage) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    try {
      final List<Map<String, String>> messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userMessage},
      ];

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: headers,
        body: json.encode({
          'model': model,
          'messages': messages,
          'stream': false,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode != 200) {
        print("📩 فشل إرسال الرسالة: ${response.body}");
        return "اعد الكلام";
      }

      final data = json.decode(utf8.decode(response.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'];
      if (content == null || content.isEmpty) {
        return "اعد الكلام";
      }

      final cleanedText = cleanResponse(content);
      print("النص بعد التنظيف: $cleanedText");

      final validResponses = {"تم التنفيذ", "0", "1", "2", "اعد الكلام"};
      if (!validResponses.contains(cleanedText)) {
        return "اعد الكلام";
      }

      return cleanedText;
    } catch (e) {
      print("🚨 خطأ في AssistantService: $e");
      return "اعد الكلام";
    }
  }

  String cleanResponse(String text) {
    return text
        .replaceAll(RegExp(r' '), ' ')
        .replaceAll(RegExp(r'&#x[0-9a-fA-F]+;'), '')
        .trim();
  }
}