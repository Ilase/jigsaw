import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:jigsaw/data/db/models/projects.dart';
import 'package:jigsaw/data/db/models/roles.dart';
import 'package:jigsaw/data/db/models/tasks.dart';
import 'package:jigsaw/data/db/models/users.dart';
import 'package:jigsaw/objectbox.g.dart';
import 'package:shelf/shelf.dart';

class Authenticator {
  final String jwtSecret;
  final Box<Roles> rolesBox;
  final Box<Users> usersBox;
  final Box<Tasks> tasksBox;
  final Box<Projects> projectsBox;

  // Временное хранилище refresh токенов (можно заменить на базу)
  final Map<String, String> _refreshTokens = {};

  Authenticator({
    required this.jwtSecret,
    required this.usersBox,
    required this.rolesBox,
    required this.tasksBox,
    required this.projectsBox,
  });

  static final _random = Random.secure();

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Access token — короткоживущий
  String generateAccessToken(String username, String role) {
    final jwt = JWT({
      'username': username,
      'role': role,
      'iat': DateTime.now().millisecondsSinceEpoch,
      'exp': DateTime.now().add(Duration(minutes: 15)).millisecondsSinceEpoch,
    });

    return jwt.sign(SecretKey(jwtSecret));
  }

  /// Refresh token — длинный, храним отдельно
  String generateRefreshToken(String username) {
    final token = base64Url.encode(
      List<int>.generate(64, (_) => _random.nextInt(256)),
    );
    _refreshTokens[username] = token;
    return token;
  }

  bool validateRefreshToken(String username, String token) {
    return _refreshTokens[username] == token;
  }

  void revokeRefreshToken(String username) {
    _refreshTokens.remove(username);
  }

  Users? validateUser(String username, String password) {
    final user =
        usersBox.query(Users_.nickname.equals(username)).build().findFirst();
    return (user != null && user.passwordHash == hashPassword(password))
        ? user
        : null;
  }

  Middleware verifyJWT({List<String> excludedPaths = const []}) {
    return (Handler innerHandler) {
      return (Request request) {
        final path = request.url.path;
        print(path);
        if (excludedPaths.any(
              (excludedPath) => path.startsWith(excludedPath),
            ) ||
            path == 'api/v1') {
          return innerHandler(request);
        }

        final authHeader = request.headers['Authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.unauthorized('No token provided');
        }

        final token = authHeader.substring(7);
        try {
          final jwt = JWT.verify(token, SecretKey(jwtSecret));

          final username = jwt.payload['username']?.toString();
          final role = jwt.payload['role']?.toString();

          if (username == null || role == null) {
            return Response.unauthorized('Token missing required fields');
          }

          print('✅ Authenticated: $username ($role)');

          final updatedRequest = request.change(
            context: {'username': username, 'role': role},
          );
          return innerHandler(updatedRequest);
        } on JWTExpiredException {
          return Response.unauthorized('Token expired');
        } on JWTException catch (e) {
          return Response.unauthorized('Invalid token: ${e.message}');
        }
      };
    };
  }
}
