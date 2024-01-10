import 'request.dart';

enum WorkStatus { Success, Interrupted ,GrammarError, WorkError, PromiseError }

enum GetResultStatus { Success, PromiseError }

typedef Work<T> = (WorkStatus, T);
typedef GetResult<T> = (GetResultStatus, T);

class AutoWorkParams {
  // 必要的请求配置
  String host;
  String path;
  RequestType type;
  Map<String, dynamic>? data;
  PostDataType? postDataType;
  List<String>? requestCookies;
  Map<String, String>? headers;

  // 必要的传递配置
  int promiseStatusCode = 200;
  AutoWorkParams Function(AutoWorkParams) Function(
      Map<String, List<String>> headers, dynamic data) transfer;
  GetResult<Map<String, dynamic>> Function(Map<String, List<String>> headers,
      dynamic data, Map<String, dynamic> result)? getResult;

  AutoWorkParams(
    this.host,
    this.path,
    this.transfer, {
    this.getResult,
    this.type = RequestType.Get,
    this.data,
    this.postDataType = PostDataType.Form,
    this.requestCookies,
    this.headers,
  });
}

Future<Work<dynamic>> autoWork(
    List<AutoWorkParams> paramsList, Request request) async {
  Map<String, dynamic> result = {};
  Work<dynamic> status = (WorkStatus.Success, null);
  paramsList.fold<dynamic>(null, (previousValue, e) async {
    if (status.$1 != WorkStatus.Success) {
      return null;
    }
    var element = previousValue(e);

    var (ioStatus, response) = await request.work(
      element.host,
      element.path,
      element.type,
      data: element.data,
      postDataType: element.postDataType,
      requestCookies: element.requestCookies,
      headers: element.headers,
    );
    if (ioStatus == IOStatus.ParamError) {
      status = (WorkStatus.GrammarError, null);
      return null;
    } else if (ioStatus == IOStatus.Success) {
      if (response.statusCode == element.promiseStatusCode) {
        if (element.getResult != null) {
          var (returnStatus, returnResult) = element.getResult!(
            response.headers,
            response.data,
            result,
          );
          result = returnResult;
          if (returnStatus != GetResultStatus.Success) {
            status = (WorkStatus.Interrupted, null);
            return null;
          }
        }
        return element.transfer(response.headers, response.data);
      } else {
        status = (WorkStatus.PromiseError, response.statusCode);
        return null;
      }
    } else {
      status = (WorkStatus.WorkError, ioStatus);
      return null;
    }
  });
  return Future<Work<dynamic>>.value(status);
}
