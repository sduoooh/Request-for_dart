import 'package:dio/dio.dart';

import 'package:dio_cookie_manager/dio_cookie_manager.dart';

enum IOStatus { Success, NetworkError, CookieError, ParamError, OtherError }

enum RequestType { Get, Post }

enum PostDataType { Form, Json, Urlencoded }

typedef IO<T> = (IOStatus, T);

class response {
  int statusCode;
  Map<String, List<String>> headers;
  dynamic data;

  response(this.statusCode, this.headers, this.data);
}

Function _getContent = (Map<String, String> data) {
  var content = '';
  data.forEach((key, value) {
    content += key + '=' + value + '&';
  });
  content = content.substring(0, content.length - 1);
  return content;
};

class _Request {
  String host = '';
  CookieManager cookies;

  _Request(this.host, this.cookies);

  Future<IO<response>> work(
    String path,
    RequestType type, {
    bool isHttps = true,
    Map<String, dynamic>? data,
    PostDataType? postDataType,
    List<String>? requestCookies,
    Map<String, String>? headers,
  }) async {
    var options = BaseOptions(
        baseUrl: 'http' + (isHttps ? 's' : '') + '://' + host,
        headers: headers,
        followRedirects: false,
        validateStatus: (status) => true);
    dynamic postData = data;
    options.method = type == RequestType.Get ? 'GET' : 'POST';
    options.headers['Host'] = host;
    if (type == RequestType.Post) {
      if (data == null)
        return Future<IO<response>>.value(
            (IOStatus.ParamError, response(0, {}, '')));

      switch (postDataType ?? PostDataType.Json) {
        case PostDataType.Form:
          options.contentType = Headers.formUrlEncodedContentType;
          postData = FormData.fromMap(data);
          break;
        case PostDataType.Json:
          options.contentType = Headers.jsonContentType;
          postData = data;
          break;
        case PostDataType.Urlencoded:
          options.contentType = Headers.formUrlEncodedContentType;
          postData = data;
          options.headers['content-length'] =
              _getContent(postData).length.toString();
          break;
      }
    }

    var dio = Dio(options);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          return handler.next(options);
        },
        onResponse: (Response response, ResponseInterceptorHandler handler) {
          return handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) {
          return handler.next(error);
        },
      ),
    );
    dio.interceptors.add(LogInterceptor(responseBody: false)); //开启请求日志
    dio.interceptors.add(cookies);
    var getResponse = await dio.request(path, data: postData);
    if ([2, 3, 4].contains(((getResponse.statusCode ?? 0) / 100).floor())) {
      return Future<IO<response>>.value((
        IOStatus.Success,
        response(getResponse.statusCode ?? 0, getResponse.headers.map,
            getResponse.data)
      ));
    } else {
      return Future<IO<response>>.value((
        IOStatus.NetworkError,
        response(getResponse.statusCode ?? 0, getResponse.headers.map,
            getResponse.data)
      ));
    }
  }
}

class Request {
  Map<String, _Request> _requests = {};
  CookieManager cookies;

  Request(this.cookies);

  Future<IO<response>> work(
    String host,
    String path,
    RequestType type, {
    Map<String, dynamic>? data,
    PostDataType? postDataType,
    Map<String, String>? headers,
  }) async {
    if (!_requests.containsKey(host)) {
      _requests[host] = _Request(host, cookies);
    }
    return Future<IO<response>>.value(await _requests[host]!.work(
      path,
      type,
      data: data,
      postDataType: postDataType,
      headers: headers,
    ));
  }
}
