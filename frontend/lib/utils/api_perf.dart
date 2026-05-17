/// PERF: Délais réseau adaptés (tunnel local / ngrok vs cloud distant).
class ApiPerf {
  ApiPerf._();

  static bool isFastApiHost(String origin) {
    final host = Uri.tryParse(origin).host.toLowerCase();
    if (host.isEmpty) return false;
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host.contains('ngrok') ||
        host.contains('loca.lt')) {
      return true;
    }
    if (host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.')) {
      return true;
    }
    return false;
  }

  static Duration backendReadyMaxWait(String origin) =>
      isFastApiHost(origin) ? const Duration(seconds: 4) : const Duration(seconds: 25);

  static Duration loginReadyMaxWait(String origin) =>
      isFastApiHost(origin) ? const Duration(seconds: 5) : const Duration(seconds: 35);

  static Duration silentRetryReadyMaxWait(String origin) =>
      isFastApiHost(origin) ? const Duration(seconds: 3) : const Duration(seconds: 20);

  static Duration healthPingTimeout(String origin) =>
      isFastApiHost(origin) ? const Duration(seconds: 3) : const Duration(seconds: 8);
}
