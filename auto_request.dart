import 'request.dart';

enum WorkStatus { Success, Interrupted, GrammarError, WorkError, PromiseError }

enum GetResultStatus { Success, PromiseError }

typedef Work<T> = (WorkStatus, T);
typedef GetResult<T> = (GetResultStatus, T);

AutoWorkParams Function(AutoWorkParams) defaultTransfer(
    Map<String, List<String>> headers,
    dynamic data,
    Map<String, dynamic> result) {
  return (e) => e;
}

GetResult<Map<String, dynamic>> defaultGetResult(
    Map<String, List<String>> headers,
    dynamic data,
    Map<String, dynamic> result) {
  return (GetResultStatus.Success, result);
}

class AutoWorkParams {
  // 必要的请求配置
  String host;
  String path;
  RequestType type;
  Map<String, String>? data;
  PostDataType? postDataType;
  //List<String>? requestCookies;
  Map<String, String>? headers;

  // 必要的传递配置
  int promiseStatusCode = 200;
  AutoWorkParams Function(AutoWorkParams) Function(
      Map<String, List<String>> headers,
      dynamic data,
      Map<String, dynamic> result) transfer;
  GetResult<Map<String, dynamic>> Function(Map<String, List<String>> headers,
      dynamic data, Map<String, dynamic> result) getResult;

  AutoWorkParams(
    this.host,
    this.path, {
    this.data,
    this.headers,
    this.promiseStatusCode = 200,
    this.type = RequestType.Get,
    this.postDataType = PostDataType.Form,
    this.transfer = defaultTransfer,
    this.getResult = defaultGetResult,
  });
}

Future<Work<dynamic>> autoWork(
    List<AutoWorkParams> paramsList, Request request) async {

  Map<String, dynamic> result = {};
  var status = WorkStatus.Success;

  await paramsList.fold<dynamic>((a) => a, (previousValue, e) async {
    AutoWorkParams element = e;
    if ((await previousValue) == null) {
      return null;
    }
    element = (await previousValue)(e);

    var (ioStatus, response) = await request.work(
      element.host,
      element.path,
      element.type,
      data: element.data,
      headers: element.headers,
      postDataType: element.postDataType,
    );
    if (ioStatus == IOStatus.ParamError) {
      status = WorkStatus.GrammarError;
      return null;
    } else if (ioStatus == IOStatus.Success) {
      if (response.statusCode == element.promiseStatusCode) {
        var (returnStatus, returnResult) = element.getResult(
          response.headers,
          response.data,
          result,
        );
        result = returnResult;
        if (returnStatus != GetResultStatus.Success) {
          status = WorkStatus.Interrupted;
          return null;
        }
        return element.transfer(response.headers, response.data, result);
      } else {
        status = WorkStatus.PromiseError;
        result["errorInfor"] = response.statusCode;
        return null;
      }
    } else {
      status = WorkStatus.WorkError;
      result['errorInfor'] = ioStatus;
      return null;
    }
  });
  return Future<Work<dynamic>>.value((status, result));
}
