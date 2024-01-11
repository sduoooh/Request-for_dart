enum CookieStatus {
  Expired,
  Valid,
  NotExist,
}

typedef cookie<T> = (CookieStatus, T);

class _Cookie {
  String name;
  String value;
  String host;
  String path = '/';
  Function? notify;
  int expires;

  _Cookie(
      this.name, this.value, this.host, this.expires, this.path, this.notify);

  @override
  String toString() {
    return '$name=$value; Domain=$host; Path=$path ;Expires=${expires.toString()}';
  }

  cookie<String> get() {
    if (DateTime.now().millisecondsSinceEpoch + 10000 > expires) {
      // 更新cookie,但是实际上需要放在另一个待用进程中进行，更多地是起到通知作用
      notify!();
      return (CookieStatus.Expired, value);
    }
    return (CookieStatus.Valid, value);
  }
}

class Cookies {
  Map<String, Map<String, List<_Cookie>>> _cookies = {};

  void add(
    String name,
    String value,
    String domain,
    int expires, {
    Function? notify = null,
    String path = '/',
  }) {
    if (!_cookies.containsKey(domain)) {
      _cookies[domain] = {
        name: [_Cookie(name, value, domain, expires, path, notify)]
      };
    } else {
      if (!_cookies[domain]!.containsKey(name)) {
        _cookies[domain]![name] = [
          _Cookie(name, value, domain, expires, path, notify)
        ];
      } else {
        var index = _cookies[domain]![name]!
            .indexWhere((element) => element.path == path);
        if (index == -1) {
          _cookies[domain]![name]!
              .add(_Cookie(name, value, domain, expires, path, notify));
        } else {
          _cookies[domain]![name]![index].value = value;
          _cookies[domain]![name]![index].expires = expires;
        }
      }
    }
  }

  cookie<(Set<(String, String)>, Map<String, List<(String, String)>>)> get(
    String domain, {
    String path = '/',
  }) {
    if (!_cookies.containsKey(domain)) {
      return (CookieStatus.NotExist, ({('NULLKEY', 'NULLVALUE')}, {}));
    }

    var cookies = _cookies[domain]!;
    Map<String, List<(String, String)>> result = {};
    Set<(String, String)> keys = {('NULLKEY', 'NULLVALUE')};
    CookieStatus returnStatus = CookieStatus.NotExist;

    path = path.startsWith('/') ? path : '/' + path;

    for (var cookie in cookies.keys) {
      var cookieList = cookies[cookie]!
          .where((element) => path.startsWith(element.path))
          .toList();
      cookieList.forEach((element) {
        var (status, value) = element.get();
        if (status == CookieStatus.Valid) {
          if (result.containsKey(cookie)) {
            result[cookie]!.add((element.path, value));
          } else {
            result[cookie] = [(element.path, value)];
          }
          keys.add((cookie, element.path));
          returnStatus = CookieStatus.Valid;
        } else {
          returnStatus = status;
        }
      });
      if (returnStatus != CookieStatus.Valid) {
        break;
      }
    }
    return (returnStatus, (keys, result));
  }

  @override
  String toString() {
    var content = '';
    _cookies.forEach((key, value) {
      value.forEach((key, value) {
        value.forEach((element) {
          content += element.toString() + ';';
        });
      });
    });
    content = content.substring(0, content.length - 1);
    return content;
  }
}
