// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:api_logger_plugin/api_logger_plugin.dart';

void main() async {
  print('=============================================');
  print('          TESTING HTTP PACKAGE               ');
  print('=============================================\n');
  await runHttpExample();

  print('\n=============================================');
  print('          TESTING DIO PACKAGE                ');
  print('=============================================\n');
  await runDioExample();
}

Future<void> runHttpExample() async {
  // 1. Initialize the default inner HTTP client
  final innerClient = http.Client();

  // 2. Wrap the inner client with HttpLoggerPlugin
  final client = HttpLoggerPlugin(
    innerClient,
    requestHeader: true,
    requestBody: true,
    responseHeader: false,
    responseBody: true,
    error: true,
    maxWidth: 90,
    enabled: true, // Tip: pass kDebugMode here
    style: LogStyle
        .pretty, // Change to compact, minimal, curl, box, developer, emoji etc.
    filter: (request) {
      // Return true to log, false to skip logging
      return true;
    },
  );

  try {
    // 3. Make HTTP requests
    await client.get(Uri.parse('https://jsonplaceholder.typicode.com/todos/1'));
  } finally {
    // 4. Close the client
    client.close();
  }
}

Future<void> runDioExample() async {
  // 1. Initialize Dio
  final dio = Dio();

  // 2. Add DioLoggerPlugin to your interceptors
  dio.interceptors.add(DioLoggerPlugin(
    requestHeader: true,
    requestBody: true,
    responseHeader: false,
    responseBody: true,
    error: true,
    maxWidth: 90,
    enabled: true, // Tip: pass kDebugMode here
    style: LogStyle.emoji, // Try out different styles!
    filter: (request) {
      // Return true to log, false to skip logging
      return true;
    },
  ));

  // 3. Make Dio requests
  try {
    await dio.get('https://jsonplaceholder.typicode.com/todos/2');
  } catch (e) {
    // Error is handled and logged by plugin automatically
  }
}
