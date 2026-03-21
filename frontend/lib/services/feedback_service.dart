import 'api_client.dart';

class FeedbackService {
  final ApiClient client = ApiClient();

  Future<bool> submit(String message, {int? rating}) async {
    final payload = {
      'message': message,
      if (rating != null) 'rating': rating,
    };
    final res = await client.post('/feedback/', payload);
    return res.statusCode == 201;
  }
}
