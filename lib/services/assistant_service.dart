import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AssistantService {
  final String apiKey = dotenv.env['OPENAI_API_KEY']!;
  final String threadId = dotenv.env['THREAD_ID']!;

  Future<String> sendMessageToAssistant(String userMessage) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'OpenAI-Beta': 'assistants=v2',
    };

    // إرسال رسالة المستخدم
    final messageResponse = await http.post(
      Uri.parse('https://api.openai.com/v1/threads/$threadId/messages'),
      headers: headers,
      body: json.encode({
        'role': 'user',
        'content': userMessage,
      }),
    );

    if (messageResponse.statusCode != 200) {
      throw Exception('فشل إرسال الرسالة: ${messageResponse.body}');
    }

    // الحصول على الرسائل للرد الأخير
    final messagesResponse = await http.get(
      Uri.parse('https://api.openai.com/v1/threads/$threadId/messages'),
      headers: headers,
    );

    if (messagesResponse.statusCode != 200) {
      throw Exception('فشل جلب الرسائل: ${messagesResponse.body}');
    }

    final messages = json.decode(messagesResponse.body)['data'];
    final lastMessage = messages.firstWhere((m) => m['role'] == 'assistant');

    return lastMessage['content'][0]['text']['value'];
  }
}