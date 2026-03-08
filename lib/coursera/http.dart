import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  var client = http.Client(); // Reuse if making multiple requests
  String greeting = 'Hello, Dart!';
  int number = 42;
  List<String> fruits = ['Apple', 'Banana', 'Cherry'];
  Map<String, int> scores = {'Alice': 90, 'Bob': 85};
  String jsonString = '{"name": "Alice", "age": 30}';
  Map<String, dynamic> user = jsonDecode(jsonString);
  print('Name: ${user['name']}');
  print('Age: ${user['age']}');

  Map<String, dynamic> newUser = {'name': 'Bob', 'age': 25};
  String newJsonString = jsonEncode(newUser);
  print(newJsonString);
  try {
    var response = await client.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      headers: {
        'User-Agent': 'MyDartApp/1.0 (https://example.com; contact@email.com)',
        'Accept': 'application/json',
      },
    );

    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      print(response.body);
    } else {
      print('Error body: ${response.body}');
    }
  } catch (e) {
    print('Exception: $e');
  } finally {
    client.close();
  }
}
