# api_logger_plugin

A highly customizable, cross-platform HTTP logger for Dart and Flutter. It intercepts and logs requests and responses for both the native `http` package and the `dio` package, bringing beautifully formatted console outputs to any project.

## The Problem It Solves

Most logging packages either lack customization, don't support both core packages, or provide dull, unreadable console outputs. 

This plugin solves that by bringing **PrettyDioLogger-like aesthetics** and extensive configurations (8 different styles, cURL generation, filtering) directly to both `http` and `dio`, saving developers hours of debugging time.

## Features

- **Supports Both `http` and `dio`**: Works perfectly with `HttpLoggerPlugin` and `DioLoggerPlugin`.
- **8 Design Styles**: Choose between `pretty`, `compact`, `minimal`, `curl`, `singleLine`, `box`, `developer`, and `emoji`.
- **cURL Command Generation**: Easily copy-paste failed requests directly to your terminal or Postman.
- **Deep Customization**: Hide/show request headers, response bodies, and adjust max console width.
- **Smart Filtering**: Log only what you want by providing a custom filter function (e.g., skip image URLs).
- **100% Cross-Platform**: Pure Dart package. Works out-of-the-box on Android, iOS, Web, macOS, Linux, and Windows.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  api_logger_plugin: ^1.0.0
  dio: ^5.0.0 # Optional, only if you are using Dio
```

## Usage

### 1. Using with the `http` package

```dart
import 'package:http/http.dart' as http;
import 'package:api_logger_plugin/api_logger_plugin.dart';

void main() async {
  final innerClient = http.Client();
  
  final client = HttpLoggerPlugin(
    innerClient,
    requestHeader: true,
    requestBody: true,
    responseHeader: false,
    responseBody: true,
    error: true,
    maxWidth: 90,
    enabled: true, // Tip: pass kDebugMode here
    style: LogStyle.pretty, // Change to: compact, minimal, curl, box, developer, emoji, singleLine
  );

  await client.get(Uri.parse('https://jsonplaceholder.typicode.com/todos/1'));
  client.close();
}
```

### 2. Using with the `dio` package

```dart
import 'package:dio/dio.dart';
import 'package:api_logger_plugin/api_logger_plugin.dart';

void main() async {
  final dio = Dio();
  
  // Add DioLoggerPlugin to your interceptors
  dio.interceptors.add(DioLoggerPlugin(
    requestHeader: true,
    requestBody: true,
    responseHeader: false,
    responseBody: true,
    error: true,
    maxWidth: 90,
    enabled: true, // Tip: pass kDebugMode here
    style: LogStyle.emoji, // Change to: pretty, compact, minimal, curl, box, developer, singleLine
  ));

  await dio.get('https://jsonplaceholder.typicode.com/todos/1');
}
```

## Log Styles

You can easily switch the look and feel of your console output by changing the `style` parameter.

### 1. `LogStyle.pretty` (Default)
The classic bordered box style, perfect for detailed debugging.

### 2. `LogStyle.compact`
Same structure as pretty, but removes the heavy border lines to save console space.

### 3. `LogStyle.box`
A premium heavy-bordered style `╔═════╗`.

### 4. `LogStyle.developer`
Structured output formatted like professional server logs (e.g., `[INFO] [HTTP-REQ]`).

### 5. `LogStyle.emoji`
Visual style using emojis like 🌐, ✅, 🚨, and 📦.

### 6. `LogStyle.minimal`
Shows only the essential information like method, status code, url, and time taken.

### 7. `LogStyle.curl`
Generates a `curl` command for your request so you can easily replay it in your terminal or Postman.

### 8. `LogStyle.singleLine`
Condenses the entire log into a single line.

## Maintainer

Maintained by **Farhan Choksi**.

## Support

If you find this package helpful, consider supporting its development:

<a href="https://www.buymeacoffee.com/farhanchoksi" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;"></a>
