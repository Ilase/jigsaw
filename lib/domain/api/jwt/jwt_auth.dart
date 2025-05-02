import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:jigsaw/data/db/models/roles.dart';
import 'package:jigsaw/data/db/models/users.dart';
import 'package:jigsaw/objectbox.g.dart';
import 'package:shelf/shelf.dart';

class Authenticator {
  final String jwtSecret;
  final Box<Roles> rolesBox;
  final Box<Users> usersBox;

  Authenticator({
    required this.jwtSecret,
    required this.usersBox,
    required this.rolesBox,
  });

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  String generateJWT(String username, String role) {
    final jwt = JWT({
      'username': username,
      'role': role,
      'iat': DateTime.now().millisecondsSinceEpoch,
      'exp': DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
    });

    return jwt.sign(SecretKey(jwtSecret));
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
        if (excludedPaths.any(
          (path) => request.requestedUri.path.endsWith(path),
        )) {
          return innerHandler(request);
        }

        final authHeader = request.headers['Authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.unauthorized('No token provided');
        }

        final token = authHeader.substring(7);
        try {
          final jwt = JWT.verify(token, SecretKey(jwtSecret));
          final username = jwt.payload['username'] as String;
          final role = jwt.payload['role'] as String;
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
