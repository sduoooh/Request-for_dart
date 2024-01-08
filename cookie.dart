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
  Function? notify;
  int expires;

  _Cookie(this.name, this.value, this.host, this.expires, this.notify);

  @override
  String toString() {
    return '$name=$value; Domain=$host; Expires=${DateTime.fromMillisecondsSinceEpoch(expires)}';
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
  Map<String, Map<String, _Cookie>> _cookies = {};

  void add(String name, String value, String domain, int expires,
      {Function? notify = null}) {
    if (!_cookies.containsKey(domain)) {
      _cookies[domain] = {name, _Cookie(name, value, domain, expires, notify)}
          as Map<String, _Cookie>;
    } else {
      if (!_cookies[domain]!.containsKey(name)) {
        _cookies[domain]![name] = _Cookie(name, value, domain, expires, notify);
      } else {
        _cookies[domain]![name]!.value = value;
        _cookies[domain]![name]!.expires = expires;
      }
    }
  }

  cookie<(Set<String>,Map<String, String>)> get(String domain) {
    if (!_cookies.containsKey(domain)) {
      return (CookieStatus.NotExist, ({}, {}));
    }

    var cookies = _cookies[domain]!;
    Map<String, String> result = {};
    Set<String> keys = {};
    CookieStatus returnStatus = CookieStatus.NotExist;

    for (var cookie in cookies.keys) {
      var (status, value) = cookies[cookie]!.get();
      if (status == CookieStatus.Valid) {
        result[cookie] = value;
        keys.add(cookie);
      } else {
        returnStatus = status;
      }
    }

    if (result != {}) {
      returnStatus = CookieStatus.Valid;
    }
    return (returnStatus, (keys, result));
  }
}
