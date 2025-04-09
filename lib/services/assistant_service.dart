import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AssistantService {
  final String apiKey = dotenv.env['OPENAI_API_KEY']!;
  final String threadId = dotenv.env['THREAD_ID']!;
  final String assistantId = dotenv.env['ASSISTANT_ID']!;

  Future<String> sendMessageToAssistant(String userMessage) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'OpenAI-Beta': 'assistants=v2',
    };

    try {
      // 1. إرسال رسالة المستخدم
      final messageResponse = await http.post(
        Uri.parse('https://api.openai.com/v1/threads/$threadId/messages'),
        headers: headers,
        body: json.encode({
          'role': 'user',
          'content': userMessage,
        }),
      );

      if (messageResponse.statusCode != 200) {
        print("📩 إرسال الرسالة فشل: ${messageResponse.body}");
        throw Exception('فشل إرسال الرسالة: ${messageResponse.statusCode}');
      }
      print("📩 تم إرسال الرسالة بنجاح");

      // 2. تشغيل المساعد
      final runResponse = await http.post(
        Uri.parse('https://api.openai.com/v1/threads/$threadId/runs'),
        headers: headers,
        body: json.encode({
          'assistant_id': assistantId,
        }),
      );

      if (runResponse.statusCode != 200) {
        print("🏃‍♂️ تشغيل فشل: ${runResponse.body}");
        throw Exception('فشل بدء تنفيذ المساعد: ${runResponse.statusCode}');
      }
      print("🏃‍♂️ تم تشغيل المساعد بنجاح");
      final runId = json.decode(runResponse.body)['id'];

      // 3. انتظار انتهاء التشغيل
      String runStatus = "queued";
      int retries = 0;

      while (runStatus != "completed" && retries < 30) {
        await Future.delayed(const Duration(seconds: 1));
        final statusResponse = await http.get(
          Uri.parse('https://api.openai.com/v1/threads/$threadId/runs/$runId'),
          headers: headers,
        );

        if (statusResponse.statusCode != 200) {
          print("📥 فشل جلب حالة التشغيل: ${statusResponse.body}");
          throw Exception('فشل متابعة حالة التشغيل: ${statusResponse.statusCode}');
        }

        runStatus = json.decode(statusResponse.body)['status'];
        print("📥 حالة التشغيل: $runStatus");
        retries++;
      }

      if (runStatus != "completed") {
        throw Exception("انتهى الوقت ولم يرد المساعد");
      }

      // 4. جلب الرسائل الجديدة
      final messagesResponse = await http.get(
        Uri.parse('https://api.openai.com/v1/threads/$threadId/messages'),
        headers: headers,
      );

      if (messagesResponse.statusCode != 200) {
        print("📩 فشل جلب الرسائل: ${messagesResponse.body}");
        throw Exception('فشل جلب الرسائل: ${messagesResponse.statusCode}');
      }

      // تحويل النص إلى UTF-8 بشكل صريح
      final messages = json.decode(utf8.decode(messagesResponse.bodyBytes));
      print("📩 الرسائل المسترجعة: $messages");
      final lastMessage = messages['data'].lastWhere((m) => m['role'] == 'assistant', orElse: () => null);

      if (lastMessage == null) {
        throw Exception("لم يتم العثور على رد من المساعد.");
      }

      final contentList = lastMessage['content'];
      if (contentList == null || contentList.isEmpty) {
        throw Exception("لا يوجد محتوى في رسالة المساعد.");
      }

      final textContent = contentList.firstWhere(
            (c) => c['type'] == 'text',
        orElse: () => null,
      );

      if (textContent == null) {
        throw Exception("رد المساعد ليس من نوع نص.");
      }

      final rawText = textContent['text']['value'];
      print("النص الخام من الـ API: $rawText");
      final cleanedText = cleanResponse(rawText);
      print("النص بعد التنظيف: $cleanedText");
      return cleanedText;
    } catch (e) {
      print("🚨 خطأ عام في AssistantService: $e");
      return "حدث خطأ";
    }
  }

  String cleanResponse(String text) {
    return text
        .replaceAll(RegExp(r' '), ' ')
        .replaceAll(RegExp(r'&#x[0-9a-fA-F]+;'), '');
  }
}
