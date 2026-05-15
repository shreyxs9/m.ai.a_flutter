import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'api_session_store.dart';

typedef JsonMap = Map<String, dynamic>;
typedef JsonParser<T> = T Function(Object? json);

class ApiClient {
  ApiClient({
    ApiConfig config = ApiConfig.defaultConfig,
    ApiSessionStore sessionStore = const ApiSessionStore(),
    Dio? dio,
  })  : _sessionStore = sessionStore,
        dio = dio ?? Dio() {
    this.dio.options = BaseOptions(
      baseUrl: config.normalizedBaseUrl,
      connectTimeout: config.timeout,
      sendTimeout: config.timeout,
      receiveTimeout: config.timeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      headers: const {
        Headers.acceptHeader: Headers.jsonContentType,
      },
    );

    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await _sessionStore.getToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              } else {
                options.headers.remove('Authorization');
              }

              final tenantId = await _sessionStore.getTenantId();
              if (tenantId != null && tenantId.isNotEmpty) {
                options.headers['X-Tenant-Id'] = tenantId;
              } else {
                options.headers.remove('X-Tenant-Id');
              }

              handler.next(options);
            },
          ),
        );
  }

  final Dio dio;
  final ApiSessionStore _sessionStore;

  Future<T?> get<T>(
    String path, {
    JsonParser<T>? parse,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return request<T>(
      path,
      method: 'GET',
      parse: parse,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<T?> post<T>(
    String path, {
    Object? body,
    JsonParser<T>? parse,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return request<T>(
      path,
      method: 'POST',
      body: body,
      parse: parse,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<T?> patch<T>(
    String path, {
    Object? body,
    JsonParser<T>? parse,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return request<T>(
      path,
      method: 'PATCH',
      body: body,
      parse: parse,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<T?> delete<T>(
    String path, {
    Object? body,
    JsonParser<T>? parse,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return request<T>(
      path,
      method: 'DELETE',
      body: body,
      parse: parse,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<T?> request<T>(
    String path, {
    required String method,
    Object? body,
    JsonParser<T>? parse,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await dio.request<Object?>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(method: method),
      );

      return _handleResponse<T>(response, parse);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  T? _handleResponse<T>(Response<Object?> response, JsonParser<T>? parse) {
    final status = response.statusCode;
    if (status == 204 || status == 205) {
      return null;
    }

    final data = _decodeBody(response.data);
    if (status == null || status < 200 || status >= 300) {
      throw ApiException(status, _errorMessage(data, response.statusMessage));
    }

    if (parse != null) {
      return parse(data);
    }

    if (data == null) {
      return null;
    }

    return data as T;
  }

  Object? _decodeBody(Object? data) {
    if (data is String && data.isNotEmpty) {
      try {
        return jsonDecode(data);
      } on FormatException {
        return data;
      }
    }
    return data;
  }

  String _errorMessage(Object? data, String? statusMessage) {
    if (data is Map) {
      final detail = data['detail'] ?? data['message'] ?? data['error'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
      if (detail != null) {
        return detail.toString();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.length > 240 ? '${data.substring(0, 240)}...' : data;
    }

    if (statusMessage != null && statusMessage.trim().isNotEmpty) {
      return statusMessage;
    }

    return 'Request failed';
  }

  ApiException _mapDioException(DioException error) {
    final status = error.response?.statusCode;
    final data = _decodeBody(error.response?.data);
    final responseMessage = _errorMessage(data, error.response?.statusMessage);

    return switch (error.type) {
      DioExceptionType.connectionTimeout => ApiException(
          status,
          'Connection timed out. Check your network and try again.',
        ),
      DioExceptionType.sendTimeout => ApiException(
          status,
          'Request timed out while sending data. Try again.',
        ),
      DioExceptionType.receiveTimeout => ApiException(
          status,
          'Server took too long to respond. Try again.',
        ),
      DioExceptionType.badResponse => ApiException(status, responseMessage),
      DioExceptionType.cancel => const ApiException(null, 'Request cancelled.'),
      DioExceptionType.connectionError => ApiException(
          status,
          'Unable to reach the server. Check your connection and try again.',
        ),
      DioExceptionType.badCertificate => ApiException(
          status,
          'Could not establish a secure connection to the server.',
        ),
      DioExceptionType.unknown => ApiException(
          status,
          error.message ?? 'Network request failed.',
        ),
    };
  }
}
