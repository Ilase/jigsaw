import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

class Authenticator {
  //TODO: remake
  final users = {
    'user1': {
      'username': 'user1',
      'password': hashPassword('password1'),
      // In real app, store hashed passwords
      'role': 'user',
    },
    'admin': {
      'username': 'admin',
      'password': hashPassword('admin123'),
      'role': 'admin',
    },
  };

  final String jwtSecret;

  Authenticator({required this.jwtSecret});

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

    String result = jwt.sign(SecretKey(jwtSecret));

    return result;
  }

  //Check of verified request and exclude some paths
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
