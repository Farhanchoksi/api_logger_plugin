// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

/// Log style designs
enum LogStyle {
  pretty, // The beautiful bordered style
  compact, // Compact bordered style (no borders, just data)
  minimal, // Only essential data without heavy lines
  curl, // Output as cURL command (request only)
  singleLine, // Everything in a single line
  box, // Heavy box style (╔═════╗)
  developer, // VS Code debug console style ([INFO] [HTTP])
  emoji // Visual style with emojis (🌐, ✅, 📦)
}

// ============================================================================
// SHARED CONSTANTS & UTILS
// ============================================================================

const _reset = '\x1B[0m';
const _red = '\x1B[31m';
const _green = '\x1B[32m';
const _yellow = '\x1B[33m';
const _blue = '\x1B[34m';
const _cyan = '\x1B[36m';
const _white = '\x1B[37m';
const _magenta = '\x1B[35m';

String _formatJson(dynamic source) {
  if (source == null) return '';
  try {
    var decoded = source;
    if (source is String) {
      decoded = jsonDecode(source);
    }
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return source.toString();
  }
}

// ============================================================================
// HTTP PLUGIN
// ============================================================================

typedef HttpFilter = bool Function(http.BaseRequest request);

class HttpLoggerPlugin extends http.BaseClient {
  final http.Client _innerClient;
  final bool requestHeader;
  final bool requestBody;
  final bool responseHeader;
  final bool responseBody;
  final bool error;
  final int maxWidth;
  final bool enabled;
  final HttpFilter? filter;
  final LogStyle style;

  HttpLoggerPlugin(
    this._innerClient, {
    this.requestHeader = true,
    this.requestBody = true,
    this.responseHeader = false,
    this.responseBody = true,
    this.error = true,
    this.maxWidth = 90,
    this.enabled = true,
    this.filter,
    this.style = LogStyle.pretty,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!enabled || (filter != null && !filter!(request))) {
      return _innerClient.send(request);
    }

    final stopwatch = Stopwatch()..start();
    _printRequest(request);

    try {
      final response = await _innerClient.send(request);
      stopwatch.stop();

      final responseBodyBytes = await response.stream.toBytes();
      final bodyString = utf8.decode(responseBodyBytes, allowMalformed: true);

      _printResponse(
          request, response, bodyString, stopwatch.elapsedMilliseconds);

      return http.StreamedResponse(
        Stream.fromIterable([responseBodyBytes]),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      stopwatch.stop();
      if (error) {
        _printError(request, e, stopwatch.elapsedMilliseconds);
      }
      rethrow;
    }
  }

  void _printRequest(http.BaseRequest request) {
    final isBox = style == LogStyle.box;
    final isCompact = style == LogStyle.compact;
    final isPretty = style == LogStyle.pretty;

    // Add start divider for unboxed styles to know where a request starts
    if (!isBox && !isPretty && !isCompact && style != LogStyle.singleLine) {
      print('$_cyan${'=' * maxWidth}$_reset');
    }

    if (style == LogStyle.curl) {
      var cmd = 'curl -X ${request.method} "${request.url}"';
      request.headers.forEach((k, v) => cmd += ' -H "$k: $v"');
      if (request is http.Request && request.body.isNotEmpty) {
        cmd += ' -d \'${request.body.replaceAll("'", "\\'")}\'';
      }
      print('$_magenta[cURL]$_reset $cmd');
      return;
    }

    if (style == LogStyle.singleLine) {
      print('$_blue[REQUEST]$_reset ${request.method} ${request.url}');
      return;
    }

    if (style == LogStyle.developer) {
      print('$_blue[INFO] [HTTP-REQ]$_reset ${request.method} ${request.url}');
      if (requestHeader && request.headers.isNotEmpty) {
        print('$_cyan${'-' * maxWidth}$_reset');
        print('$_yellow[HEADERS]$_reset ${request.headers}');
      }
      if (requestBody && request is http.Request && request.body.isNotEmpty) {
        print('$_cyan${'-' * maxWidth}$_reset');
        print('$_white[BODY]\n${_formatJson(request.body)}$_reset');
      }
      return;
    }

    if (style == LogStyle.emoji) {
      print('🌐 $_blue${request.method}$_reset ${request.url}');
      if (requestHeader && request.headers.isNotEmpty) {
        request.headers
            .forEach((k, v) => print('  🏷️  $_yellow$k: $v$_reset'));
      }
      if (requestBody && request is http.Request && request.body.isNotEmpty) {
        print(
            '  📤 $_white${_formatJson(request.body).replaceAll('\n', '\n  ')}$_reset');
      }
      return;
    }

    if (style == LogStyle.minimal) {
      print('$_blue--> ${request.method} ${request.url}$_reset');
      if (requestHeader && request.headers.isNotEmpty) {
        request.headers.forEach((k, v) => print('$_yellow$k: $v$_reset'));
      }
      if (requestBody && request is http.Request && request.body.isNotEmpty) {
        print('$_white${_formatJson(request.body)}$_reset');
      }
      return;
    }

    final border =
        isCompact ? '' : (isBox ? '$_cyan║$_reset ' : '$_cyan│$_reset ');
    final topBorder = isCompact
        ? '$_cyan${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_cyan╔${'═' * maxWidth}$_reset'
            : '$_cyan┌${'─' * maxWidth}$_reset');
    final bottomBorder = isCompact
        ? '$_cyan${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_cyan╚${'═' * maxWidth}$_reset'
            : '$_cyan└${'─' * maxWidth}$_reset');
    final midBorder = isCompact
        ? ''
        : (isBox
            ? '$_cyan╠${'═' * maxWidth}$_reset'
            : '$_cyan├${'─' * maxWidth}$_reset');

    if (topBorder.isNotEmpty) print(topBorder);
    print('$border$_blue REQUEST │ ${request.method} $_reset');
    print('$border$_white ${request.url} $_reset');

    if (midBorder.isNotEmpty) print(midBorder);
    print('$border$_yellow Options $_reset');

    final cLen = request.contentLength != null
        ? '${request.contentLength} bytes'
        : 'Not Set';
    print('$border$_white Content-Length: $cLen $_reset');

    if (requestHeader && request.headers.isNotEmpty) {
      if (midBorder.isNotEmpty) print(midBorder);
      print('$border$_yellow Headers $_reset');
      request.headers.forEach((k, v) => print('$border$_white $k: $v $_reset'));
    }

    if (requestBody && request is http.Request && request.body.isNotEmpty) {
      if (midBorder.isNotEmpty) print(midBorder);
      print('$border$_blue Body $_reset');
      print(
          '$border$_white ${_formatJson(request.body).replaceAll('\n', '\n$border$_white')} $_reset');
    }
    if (bottomBorder.isNotEmpty) print(bottomBorder);
  }

  void _printResponse(http.BaseRequest request, http.StreamedResponse response,
      String bodyStr, int ms) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    final statusColor = isSuccess ? _green : _red;

    if (style == LogStyle.singleLine) {
      print(
          '$statusColor[RESPONSE]$_reset ${response.statusCode} | $ms ms | ${request.url}');
      return;
    }

    if (style == LogStyle.curl) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '$statusColor[RESPONSE]$_reset ${response.statusCode} | $ms ms | ${request.url}');
      if (responseBody && bodyStr.isNotEmpty) {
        print('$_white${_formatJson(bodyStr)}$_reset');
      }
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.developer) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '$statusColor[INFO] [HTTP-RES]$_reset ${response.statusCode} | $ms ms | ${request.url}');
      if (responseHeader && response.headers.isNotEmpty) {
        print('$_cyan${'-' * maxWidth}$_reset');
        print('$_yellow[HEADERS]$_reset ${response.headers}');
      }
      if (responseBody && bodyStr.isNotEmpty) {
        print('$_cyan${'-' * maxWidth}$_reset');
        print('$statusColor[BODY]\n${_formatJson(bodyStr)}$_reset');
      }
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.emoji) {
      print('$_cyan${'-' * maxWidth}$_reset');
      final icon = isSuccess ? '✅' : '❌';
      print(
          '$icon $statusColor${response.statusCode}$_reset ⏱️ $_yellow${ms}ms$_reset ${request.url}');
      if (responseHeader && response.headers.isNotEmpty) {
        response.headers
            .forEach((k, v) => print('  🏷️  $_yellow$k: $v$_reset'));
      }
      if (responseBody && bodyStr.isNotEmpty) {
        print(
            '  📦 $_green${_formatJson(bodyStr).replaceAll('\n', '\n  ')}$_reset');
      }
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.minimal) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '$statusColor<-- ${response.statusCode} ${request.url} ($ms ms)$_reset');
      if (responseHeader && response.headers.isNotEmpty) {
        response.headers.forEach((k, v) => print('$_yellow$k: $v$_reset'));
      }
      if (responseBody && bodyStr.isNotEmpty) {
        print('$_green${_formatJson(bodyStr)}$_reset');
      }
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    final isBox = style == LogStyle.box;
    final isCompact = style == LogStyle.compact;
    final border =
        isCompact ? '' : (isBox ? '$_cyan║$_reset ' : '$_cyan│$_reset ');
    final topBorder = isCompact
        ? '$_cyan${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_cyan╔${'═' * maxWidth}$_reset'
            : '$_cyan┌${'─' * maxWidth}$_reset');
    final bottomBorder = isCompact
        ? '$_cyan${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_cyan╚${'═' * maxWidth}$_reset'
            : '$_cyan└${'─' * maxWidth}$_reset');
    final midBorder = isCompact
        ? ''
        : (isBox
            ? '$_cyan╠${'═' * maxWidth}$_reset'
            : '$_cyan├${'─' * maxWidth}$_reset');

    if (topBorder.isNotEmpty) print(topBorder);
    print('$border$statusColor RESPONSE │ ${response.statusCode} $_reset');
    print('$border$_yellow Time: $ms ms $_reset');
    print('$border$_white ${request.url} $_reset');

    if (responseHeader && response.headers.isNotEmpty) {
      if (midBorder.isNotEmpty) print(midBorder);
      print('$border$_yellow Headers $_reset');
      response.headers
          .forEach((k, v) => print('$border$_white $k: $v $_reset'));
    }

    if (responseBody && bodyStr.isNotEmpty) {
      if (midBorder.isNotEmpty) print(midBorder);
      print('$border$_blue BODY $_reset');
      print(
          '$border$_green ${_formatJson(bodyStr).replaceAll('\n', '\n$border$_green')} $_reset');
    }
    if (bottomBorder.isNotEmpty) print(bottomBorder);
  }

  void _printError(http.BaseRequest request, Object e, int ms) {
    if (style == LogStyle.singleLine) {
      print(
          '$_red[ERROR]$_reset ${request.method} ${request.url} | $ms ms | $e');
      return;
    }

    if (style == LogStyle.curl) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '$_red[ERROR]$_reset ${request.method} ${request.url} | $ms ms | $e');
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.developer) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '$_red[ERROR] [HTTP]$_reset ${request.method} ${request.url} | $ms ms\n$_red$e$_reset');
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.emoji) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '🚨 $_red${request.method}$_reset ⏱️ $_yellow${ms}ms$_reset ${request.url}');
      print('  🔥 $_red$e$_reset');
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.minimal) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print('$_red<-- ERROR ${request.method} ${request.url} ($ms ms)$_reset');
      print('$_red$e$_reset');
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    final isBox = style == LogStyle.box;
    final isCompact = style == LogStyle.compact;
    final border =
        isCompact ? '' : (isBox ? '$_red║$_reset ' : '$_red│$_reset ');
    final topBorder = isCompact
        ? '$_red${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_red╔${'═' * maxWidth}$_reset'
            : '$_red┌${'─' * maxWidth}$_reset');
    final bottomBorder = isCompact
        ? '$_red${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_red╚${'═' * maxWidth}$_reset'
            : '$_red└${'─' * maxWidth}$_reset');

    if (topBorder.isNotEmpty) print(topBorder);
    print('$border$_red ERROR │ ${request.method} │ $ms ms $_reset');
    print('$border$_white ${request.url} $_reset');
    print('$border$_red $e $_reset');
    if (bottomBorder.isNotEmpty) print(bottomBorder);
  }
}

// ============================================================================
// DIO PLUGIN
// ============================================================================

typedef DioFilter = bool Function(RequestOptions options);

class DioLoggerPlugin extends Interceptor {
  final bool requestHeader;
  final bool requestBody;
  final bool responseHeader;
  final bool responseBody;
  final bool error;
  final int maxWidth;
  final bool enabled;
  final DioFilter? filter;
  final LogStyle style;

  DioLoggerPlugin({
    this.requestHeader = true,
    this.requestBody = true,
    this.responseHeader = false,
    this.responseBody = true,
    this.error = true,
    this.maxWidth = 90,
    this.enabled = true,
    this.filter,
    this.style = LogStyle.pretty,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!enabled || (filter != null && !filter!(options))) {
      return handler.next(options);
    }
    options.extra['start_time'] = DateTime.now().millisecondsSinceEpoch;
    _printRequest(options);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!enabled || (filter != null && !filter!(response.requestOptions))) {
      return handler.next(response);
    }
    final ms = DateTime.now().millisecondsSinceEpoch -
        (response.requestOptions.extra['start_time'] as int? ??
            DateTime.now().millisecondsSinceEpoch);
    _printResponse(response, ms);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!enabled || (filter != null && !filter!(err.requestOptions))) {
      return handler.next(err);
    }
    final ms = DateTime.now().millisecondsSinceEpoch -
        (err.requestOptions.extra['start_time'] as int? ??
            DateTime.now().millisecondsSinceEpoch);
    if (error) {
      _printError(err, ms);
    }
    handler.next(err);
  }

  void _printRequest(RequestOptions request) {
    final isBox = style == LogStyle.box;
    final isCompact = style == LogStyle.compact;
    final isPretty = style == LogStyle.pretty;

    // Add start divider for unboxed styles to know where a request starts
    if (!isBox && !isPretty && !isCompact && style != LogStyle.singleLine) {
      print('$_cyan${'=' * maxWidth}$_reset');
    }

    if (style == LogStyle.curl) {
      var cmd = 'curl -X ${request.method} "${request.uri}"';
      request.headers.forEach((k, v) => cmd += ' -H "$k: $v"');
      if (request.data != null) {
        final data = _formatJson(request.data);
        cmd += ' -d \'${data.replaceAll("'", "\\'")}\'';
      }
      print('$_magenta[cURL]$_reset $cmd');
      return;
    }

    if (style == LogStyle.singleLine) {
      print('$_blue[REQUEST]$_reset ${request.method} ${request.uri}');
      return;
    }

    if (style == LogStyle.developer) {
      print('$_blue[INFO] [HTTP-REQ]$_reset ${request.method} ${request.uri}');
      if (requestHeader && request.headers.isNotEmpty) {
        print('$_cyan${'-' * maxWidth}$_reset');
        print('$_yellow[HEADERS]$_reset ${request.headers}');
      }
      if (requestBody && request.data != null) {
        print('$_cyan${'-' * maxWidth}$_reset');
        print('$_white[BODY]\n${_formatJson(request.data)}$_reset');
      }
      return;
    }

    if (style == LogStyle.emoji) {
      print('🌐 $_blue${request.method}$_reset ${request.uri}');
      if (requestHeader && request.headers.isNotEmpty) {
        request.headers
            .forEach((k, v) => print('  🏷️  $_yellow$k: $v$_reset'));
      }
      if (requestBody && request.data != null) {
        print(
            '  📤 $_white${_formatJson(request.data).replaceAll('\n', '\n  ')}$_reset');
      }
      return;
    }

    if (style == LogStyle.minimal) {
      print('$_blue--> ${request.method} ${request.uri}$_reset');
      if (requestHeader && request.headers.isNotEmpty) {
        request.headers.forEach((k, v) => print('$_yellow$k: $v$_reset'));
      }
      if (requestBody && request.data != null) {
        print('$_white${_formatJson(request.data)}$_reset');
      }
      return;
    }

    final border =
        isCompact ? '' : (isBox ? '$_cyan║$_reset ' : '$_cyan│$_reset ');
    final topBorder = isCompact
        ? '$_cyan${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_cyan╔${'═' * maxWidth}$_reset'
            : '$_cyan┌${'─' * maxWidth}$_reset');
    final bottomBorder = isCompact
        ? '$_cyan${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_cyan╚${'═' * maxWidth}$_reset'
            : '$_cyan└${'─' * maxWidth}$_reset');
    final midBorder = isCompact
        ? ''
        : (isBox
            ? '$_cyan╠${'═' * maxWidth}$_reset'
            : '$_cyan├${'─' * maxWidth}$_reset');

    if (topBorder.isNotEmpty) print(topBorder);
    print('$border$_blue REQUEST │ ${request.method} $_reset');
    print('$border$_white ${request.uri} $_reset');

    if (midBorder.isNotEmpty) print(midBorder);
    print('$border$_yellow Options $_reset');

    final cType = request.contentType ?? 'Not Set';
    print('$border$_white Content-Type: $cType $_reset');

    print('$border$_white Response-Type: ${request.responseType.name} $_reset');

    final cTimeout = request.connectTimeout != null
        ? '${request.connectTimeout?.inMilliseconds} ms'
        : 'Not Set';
    print('$border$_white Connect-Timeout: $cTimeout $_reset');

    final rTimeout = request.receiveTimeout != null
        ? '${request.receiveTimeout?.inMilliseconds} ms'
        : 'Not Set';
    print('$border$_white Receive-Timeout: $rTimeout $_reset');

    final sTimeout = request.sendTimeout != null
        ? '${request.sendTimeout?.inMilliseconds} ms'
        : 'Not Set';
    print('$border$_white Send-Timeout: $sTimeout $_reset');

    if (requestHeader && request.headers.isNotEmpty) {
      if (midBorder.isNotEmpty) print(midBorder);
      print('$border$_yellow Headers $_reset');
      request.headers.forEach((k, v) => print('$border$_white $k: $v $_reset'));
    }

    if (requestBody && request.data != null) {
      if (midBorder.isNotEmpty) print(midBorder);
      print('$border$_blue Body $_reset');
      print(
          '$border$_white ${_formatJson(request.data).replaceAll('\n', '\n$border$_white')} $_reset');
    }
    if (bottomBorder.isNotEmpty) print(bottomBorder);
  }

  void _printResponse(Response response, int ms) {
    final isSuccess =
        (response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300;
    final statusColor = isSuccess ? _green : _red;
    final uri = response.requestOptions.uri;

    if (style == LogStyle.singleLine) {
      print(
          '$statusColor[RESPONSE]$_reset ${response.statusCode} | $ms ms | $uri');
      return;
    }

    if (style == LogStyle.curl) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '$statusColor[RESPONSE]$_reset ${response.statusCode} | $ms ms | $uri');
      if (responseBody && response.data != null) {
        print('$_white${_formatJson(response.data)}$_reset');
      }
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.developer) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '$statusColor[INFO] [HTTP-RES]$_reset ${response.statusCode} | $ms ms | $uri');
      if (responseHeader && response.headers.map.isNotEmpty) {
        print('$_cyan${'-' * maxWidth}$_reset');
        print('$_yellow[HEADERS]$_reset ${response.headers.map}');
      }
      if (responseBody && response.data != null) {
        print('$_cyan${'-' * maxWidth}$_reset');
        print('$statusColor[BODY]\n${_formatJson(response.data)}$_reset');
      }
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.emoji) {
      print('$_cyan${'-' * maxWidth}$_reset');
      final icon = isSuccess ? '✅' : '❌';
      print(
          '$icon $statusColor${response.statusCode}$_reset ⏱️ $_yellow${ms}ms$_reset $uri');
      if (responseHeader && response.headers.map.isNotEmpty) {
        response.headers.map
            .forEach((k, v) => print('  🏷️  $_yellow$k: $v$_reset'));
      }
      if (responseBody && response.data != null) {
        print(
            '  📦 $_green${_formatJson(response.data).replaceAll('\n', '\n  ')}$_reset');
      }
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.minimal) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print('$statusColor<-- ${response.statusCode} $uri ($ms ms)$_reset');
      if (responseHeader && response.headers.map.isNotEmpty) {
        response.headers.map.forEach((k, v) => print('$_yellow$k: $v$_reset'));
      }
      if (responseBody && response.data != null) {
        print('$_green${_formatJson(response.data)}$_reset');
      }
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    final isBox = style == LogStyle.box;
    final isCompact = style == LogStyle.compact;
    final border =
        isCompact ? '' : (isBox ? '$_cyan║$_reset ' : '$_cyan│$_reset ');
    final topBorder = isCompact
        ? '$_cyan${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_cyan╔${'═' * maxWidth}$_reset'
            : '$_cyan┌${'─' * maxWidth}$_reset');
    final bottomBorder = isCompact
        ? '$_cyan${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_cyan╚${'═' * maxWidth}$_reset'
            : '$_cyan└${'─' * maxWidth}$_reset');
    final midBorder = isCompact
        ? ''
        : (isBox
            ? '$_cyan╠${'═' * maxWidth}$_reset'
            : '$_cyan├${'─' * maxWidth}$_reset');

    if (topBorder.isNotEmpty) print(topBorder);
    print('$border$statusColor RESPONSE │ ${response.statusCode} $_reset');
    print('$border$_yellow Time: $ms ms $_reset');
    print('$border$_white $uri $_reset');

    if (responseHeader && response.headers.map.isNotEmpty) {
      if (midBorder.isNotEmpty) print(midBorder);
      print('$border$_yellow Headers $_reset');
      response.headers.map
          .forEach((k, v) => print('$border$_white $k: $v $_reset'));
    }

    if (responseBody && response.data != null) {
      if (midBorder.isNotEmpty) print(midBorder);
      print('$border$_blue BODY $_reset');
      print(
          '$border$_green ${_formatJson(response.data).replaceAll('\n', '\n$border$_green')} $_reset');
    }
    if (bottomBorder.isNotEmpty) print(bottomBorder);
  }

  void _printError(DioException err, int ms) {
    final request = err.requestOptions;
    if (style == LogStyle.singleLine) {
      print(
          '$_red[ERROR]$_reset ${request.method} ${request.uri} | $ms ms | ${err.message}');
      return;
    }

    if (style == LogStyle.curl) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '$_red[ERROR]$_reset ${request.method} ${request.uri} | $ms ms | ${err.message}');
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.developer) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '$_red[ERROR] [HTTP]$_reset ${request.method} ${request.uri} | $ms ms\n$_red${err.message}$_reset');
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.emoji) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print(
          '🚨 $_red${request.method}$_reset ⏱️ $_yellow${ms}ms$_reset ${request.uri}');
      print('  🔥 $_red${err.message}$_reset');
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    if (style == LogStyle.minimal) {
      print('$_cyan${'-' * maxWidth}$_reset');
      print('$_red<-- ERROR ${request.method} ${request.uri} ($ms ms)$_reset');
      print('$_red${err.message}$_reset');
      print('$_cyan${'-' * maxWidth}$_reset');
      return;
    }

    final isBox = style == LogStyle.box;
    final isCompact = style == LogStyle.compact;
    final border =
        isCompact ? '' : (isBox ? '$_red║$_reset ' : '$_red│$_reset ');
    final topBorder = isCompact
        ? '$_red${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_red╔${'═' * maxWidth}$_reset'
            : '$_red┌${'─' * maxWidth}$_reset');
    final bottomBorder = isCompact
        ? '$_red${'─' * maxWidth}$_reset'
        : (isBox
            ? '$_red╚${'═' * maxWidth}$_reset'
            : '$_red└${'─' * maxWidth}$_reset');

    if (topBorder.isNotEmpty) print(topBorder);
    print('$border$_red ERROR │ ${request.method} │ $ms ms $_reset');
    print('$border$_white ${request.uri} $_reset');
    print('$border$_red ${err.message} $_reset');
    if (bottomBorder.isNotEmpty) print(bottomBorder);
  }
}
