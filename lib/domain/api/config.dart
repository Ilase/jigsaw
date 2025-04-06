import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> loadConfig(String filepath) async {
  final file = File(filepath);
  final jsonString = await file.readAsString();
  return jsonDecode(jsonString);
}
