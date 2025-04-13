import 'dart:convert';

import 'package:jigsaw/domain/api/jwt/jwt_auth.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class ApiService {
  Authenticator auth;
  final Router _router;
  late final handler;

  ApiService({required this.auth}) : _router = Router() {
    _setupRoutes();
    handler = const Pipeline()
        .addMiddleware(
          logRequests(
            logger: (line, f) {
              print("$line + || + ${f.toString()}");
            },
          ),
        )
        .addMiddleware(auth.verifyJWT(excludedPaths: ['/login', '/']))
        .addHandler(_router.call);
    _router.mount('/api/v1', handler);
  }

  void _setupRoutes() {
    _router.post('/login', _login);
    _router.get('/home', _home);
    _router.get('/', _slash);
  }

  Future<Response> _login(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    //Get credentials
    final username = data['username'] as String;
    final password = data['password'] as String;

    if (!auth.users.containsKey(username) ||
        auth.users[username]!['password'] !=
            Authenticator.hashPassword(password)) {
      return Response.unauthorized('Invalid credentials');
    }
    final user = auth.users[username]!;
    final String role = user['role'] as String;
    final token = auth.generateJWT(username, role);

    return Response.ok(
      jsonEncode({"jigsawVersion": "0.1.0", "token": token}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _home(Request request) async {
    return Response.ok(jsonEncode({'home': 'this sis'}));
  }

  Future<Response> _slash(Request request) async {
    return Response.ok(jsonEncode({'gigi': 'g'}));
  }
}
