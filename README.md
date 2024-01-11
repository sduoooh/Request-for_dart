# Request-with-cookies-manager
A simple request lib with cookies manager in Dart, base on Dio.dart.
Cookies manager replaced by CookieManager.
And because it, we can not easy to keep track of the possession and use of our cookies，some return status needs redesigned.

# Auto-request

Base on List.fold, it realizes auto-request function.
In fact, it only pre-do some non-logical work, like errors handler, params transfer and so on.


