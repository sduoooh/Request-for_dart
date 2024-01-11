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

    // Set<(String, String)> keys = {('NULLKEY', 'NULLVALUE')};
    // Map<String, List<(String, String)>> results = {};

    // requestCookies = requestCookies ?? [];
    // requestCookies.forEach((element) {
    //   var (_, result) = cookies.get(host, path: path);
    //   keys.addAll(result.$1);
    //   results.addAll(result.$2);
    // });

    // if (keys.containsAll(requestCookies)) {
    //   var cookieString = '';
    //   (requestCookies).forEach((e) {
    //     results[e]!.forEach((element) {
    //       cookieString += e + '=' + element.$2 + ';';
    //     });
    //   });
    //   if (cookieString.length > 0) {
    //     options.headers['Cookie'] = cookieString;
    //   }
    // } else {
    //   return Future<IO<response>>.value(
    //       (IOStatus.CookieError, response(0, {}, '')));
    // }
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
          // 如果你想终止请求并触发一个错误，你可以使用 `handler.reject(error)`。
          return handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) {
          // 如果你想完成请求并返回一些自定义数据，你可以使用 `handler.resolve(response)`。
          return handler.next(error);
        },
      ),
    );
    dio.interceptors.add(LogInterceptor(responseBody: false)); //开启请求日志
    dio.interceptors.add(cookies);
    var getResponse = await dio.request(path, data: postData);
    if ([2, 3, 4].contains(((getResponse.statusCode ?? 0) / 100).floor())) {
      // if (getResponse.headers.map.containsKey('set-cookie')) {
      //   var cookie = getResponse.headers.map['set-cookie'];
      //   cookie!.forEach((element) {
      //     var info = element.split(';');
      //     var path =
      //         info.indexWhere((element) => element.startsWith('path'), 1);

      //     cookies.add(info[0].split('=')[0], info[0].split('=')[1], host,
      //         double.maxFinite.toInt(),
      //         path: (path == -1) ? '/' : info[path].split('=')[1]);
      //   });
      // }
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
    //List<String>? requestCookies,
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
      //requestCookies: requestCookies,
      headers: headers,
    ));
  }
}
