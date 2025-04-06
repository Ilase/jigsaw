import 'dart:convert';

import 'package:jigsaw/data/j_logger.dart';
import 'package:jigsaw/domain/api/config.dart';
import 'package:jigsaw/domain/api/jwt/jwt_auth.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

void main(List<String> args) async {
  ///Loading configuration file with port and jwtSecret key
  final config = await loadConfig('config/config.json');

  ///Setting up auth middleware
  final auth = Authenticator(jwtSecret: config["secret"]);

  jLogger.i("Server configuration: \n $config");

  final api = Router();
  //Handler for all requests
  final handler = const Pipeline()
      .addMiddleware(
        logRequests(
          logger: (line, f) {
            print("$line + || + ${f.toString()}");
          },
        ),
      )
      .addMiddleware(auth.verifyJWT(excludedPaths: ['/login', '/']))
      .addHandler(api.call);

  api.post('/login', (Request request) async {
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
  });
  api.get('/home', (Request request) {
    return Response.ok(
      jsonEncode({"jigsawVersion": "0.1.0"}),
      headers: {'Content-Type': 'application/json'},
    );
  });

  final server = await serve(handler, "localhost", config["port"]);
  print('Server listening on port ${server.port}');
}
