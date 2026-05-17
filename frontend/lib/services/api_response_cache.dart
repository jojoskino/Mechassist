/// Cache mémoire des réponses API fréquentes (évite les appels répétés).
class ApiResponseCache {
  ApiResponseCache._();

  static Map<String, dynamic>? _me;
  static String? _meToken;
  static DateTime? _meAt;
  static const _meTtl = Duration(minutes: 3);

  static final _messages = <int, List<dynamic>>{};
  static final _messagesAt = <int, DateTime>{};
  static const _messagesTtl = Duration(seconds: 8);

  static final _requests = <int, Map<String, dynamic>>{};
  static final _requestsAt = <int, DateTime>{};
  static const _requestTtl = Duration(seconds: 15);

  static Map<String, dynamic>? meIfFresh(String token) {
    if (_me == null || _meToken != token || _meAt == null) return null;
    if (DateTime.now().difference(_meAt!) > _meTtl) return null;
    return Map<String, dynamic>.from(_me!);
  }

  static void putMe(String token, Map<String, dynamic> data) {
    _meToken = token;
    _me = Map<String, dynamic>.from(data);
    _meAt = DateTime.now();
  }

  static void invalidateMe() {
    _me = null;
    _meToken = null;
    _meAt = null;
  }

  static List<dynamic>? messagesIfFresh(int requestId) {
    final at = _messagesAt[requestId];
    if (at == null || DateTime.now().difference(at) > _messagesTtl) return null;
    final list = _messages[requestId];
    return list == null ? null : List<dynamic>.from(list);
  }

  static void putMessages(int requestId, List<dynamic> data) {
    _messages[requestId] = List<dynamic>.from(data);
    _messagesAt[requestId] = DateTime.now();
  }

  static Map<String, dynamic>? requestIfFresh(int id) {
    final at = _requestsAt[id];
    if (at == null || DateTime.now().difference(at) > _requestTtl) return null;
    final m = _requests[id];
    return m == null ? null : Map<String, dynamic>.from(m);
  }

  static void putRequest(int id, Map<String, dynamic> data) {
    _requests[id] = Map<String, dynamic>.from(data);
    _requestsAt[id] = DateTime.now();
  }

  static void invalidateMessages(int requestId) {
    _messages.remove(requestId);
    _messagesAt.remove(requestId);
  }

  static void clear() {
    invalidateMe();
    _messages.clear();
    _messagesAt.clear();
    _requests.clear();
    _requestsAt.clear();
  }
}
