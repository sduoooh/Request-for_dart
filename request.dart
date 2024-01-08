import 'package:dio/dio.dart';

import 'cookie.dart';

enum IOStatus { Success, NetworkError, CookieError, ParamError, OtherError }

enum RequestType { Get, Post }

enum PostDataType { Form, Json, Urlencoded }

typedef IO<T> = (IOStatus, T);

class response {
  int statusCode;
  Map<String, List<String>> headers;
  String data;

  response(this.statusCode, this.headers, this.data);
}

class _request {
  String host = '';
  Cookies cookies;
  Dio dio;

  _request(this.host, this.cookies)
      : dio = Dio(BaseOptions(
            baseUrl: "https://" + host,
            followRedirects: false,
            validateStatus: (status) => true));

  Future<IO<response>> work(
    String path,
    RequestType type, {
    Map<String, dynamic>? data,
    PostDataType? postDataType,
    List<String>? requestCookies,
    Map<String, String>? headers,
  }) async {
    var options = Options(headers: headers);
    dynamic postData = data;
    options.method = type == RequestType.Get ? 'GET' : 'POST';
    var (status, (keys, cookie)) = cookies.get(host);
    if (status != CookieStatus.Valid) {
      return Future<IO<response>>.value(
          (IOStatus.CookieError, response(0, {}, '')));
    }
    if (keys.containsAll(requestCookies ?? [])) {
      var cookieString = '';
      requestCookies?.forEach((element) {
        cookieString += element + '=' + cookie[element]! + ';';
      });
      options.headers!['Cookie'] = cookieString;
    } else {
      return Future<IO<response>>.value(
          (IOStatus.CookieError, response(0, {}, '')));
    }
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
          break;
      }
    }

    //  不晓得dio的实例options内容是否会被单次请求options完全覆盖，有bug可以考虑考虑这里
    var getResponse = await dio.request(path, options: options, data: postData);
    if ([2, 3, 4].contains((getResponse.statusCode ?? 0 / 100).floor())) {
      if (getResponse.headers.map.containsKey('set-cookie')) {
        var cookie = getResponse.headers.map['set-cookie'];
        cookie!.forEach((element) {
          var info = element
              .split(';')[0]
              .split('='); // 目前需要的cookie均为会话中产生的本path下cookie，因此只取其值
          cookies.add(info[0], info[1], host, 0);
        });
      }
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
