import 'dart:convert';

import 'package:jigsaw/data/db/models/roles.dart';
import 'package:jigsaw/data/db/models/users.dart';
import 'package:jigsaw/domain/api/jwt/jwt_auth.dart';
import 'package:jigsaw/objectbox.g.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class ApiService {
  Authenticator auth;
  final Router _router;
  late final Handler handler;

  ApiService({required this.auth}) : _router = Router() {
    _setupRoutes();
    handler = const Pipeline()
        .addMiddleware(
          logRequests(
            logger: (line, f) {
              print("$line || ${f.toString()}");
            },
          ),
        )
        ///JWT middleware
        .addMiddleware(auth.verifyJWT(excludedPaths: ['/login', '/']))
        .addHandler(_router.call);

    _router.mount('/api/v1', handler);
  }

  bool _isAdmin(Request request) {
    return request.context['role'] == 'admin';
  }

  void _setupRoutes() {
    ///not saved
    _router.post('/api/v1/login', _login);

    /// saved routes
    _router.get('/api/v1/users', _getAllUsers);
    _router.get('/api/v1/users/me', _getCurrentUser);
    _router.post('/api/v1/users', _createUser); // Создание
    _router.delete('/api/v1/users/<nickname>', _deleteUser); // Удаление
    _router.patch('/api/v1/users/root/password', _changeRootPass);
  }

  Future<Response> _login(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final username = data['username'] as String;
    final password = data['password'] as String;

    final user = auth.validateUser(username, password);
    if (user == null) {
      return Response.unauthorized('Invalid credentials');
    }

    final roleName = user.role.target?.name ?? 'unknown';
    final token = auth.generateJWT(user.nickname, roleName);
    return Response.ok(
      jsonEncode({"jigsawVersion": "0.1.0", "token": token}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _getAllUsers(Request request) async {
    if (!_isAdmin(request)) {
      return Response.forbidden('Admin access required');
    }

    final users =
        auth.usersBox
            .getAll()
            .map(
              (u) => {
                'nickname': u.nickname,
                'role': u.role.target?.name,
                'fName': u.fName,
                'lName': u.lName,
              },
            )
            .toList();

    return Response.ok(
      jsonEncode({'users': users}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _getCurrentUser(Request request) async {
    final nickname = request.context['username'] as String;

    final user =
        auth.usersBox
            .query(Users_.nickname.equals(nickname))
            .build()
            .findFirst();

    if (user == null) {
      return Response.internalServerError(body: 'User not found');
    }

    return Response.ok(
      jsonEncode({
        'nickname': user.nickname,
        'role': user.role,
        'fName': user.fName,
        'lName': user.lName,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _createUser(Request request) async {
    if (!_isAdmin(request)) {
      return Response.forbidden('Admin access required');
    }
    final payload = await request.readAsString();
    final data = jsonDecode(payload) as Map<String, dynamic>;

    final nickname = data['nickname'];
    final password = data['password'];
    final roleName = data['role'];
    final Roles? role =
        auth.rolesBox.query(Roles_.name.equals(roleName)).build().findFirst();
    final fName = data['fName'];
    final lName = data['lName'];

    if (nickname == null || password == null || role == null) {
      return Response(400, body: 'Missing required fields');
    }

    final existing =
        auth.usersBox
            .query(Users_.nickname.equals(nickname))
            .build()
            .findFirst();

    if (existing != null) {
      return Response(409, body: 'User already exists');
    }
    if (role == null) {
      return Response(400, body: 'Invalid role');
    }
    final user = Users(
      nickname: nickname,
      passwordHash: Authenticator.hashPassword(password),
      fName: fName,
      lName: lName,
    )..role.target = role;

    auth.usersBox.put(user);
    return Response.ok('User created');
  }

  Future<Response> _deleteUser(Request request, String nickname) async {
    //Wth
    // final contextUser = request.context['username'] as String;
    if (!_isAdmin(request)) {
      return Response.forbidden('Admin access required');
    }
    if (nickname == 'root') {
      return Response.forbidden('Cannot delete root user');
    }

    final user =
        auth.usersBox
            .query(Users_.nickname.equals(nickname))
            .build()
            .findFirst();

    if (user == null) {
      return Response.notFound('User not found');
    }

    auth.usersBox.remove(user.id);
    return Response.ok('User deleted');
  }

  Future<Response> _changeRootPass(Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload) as Map<String, dynamic>;

    final current = data['currentPassword'];
    final newPass = data['newPassword'];

    if (current == null || newPass == null) {
      return Response(400, body: 'Missing fields');
    }

    final root =
        auth.usersBox.query(Users_.nickname.equals('root')).build().findFirst();

    if (root == null) {
      return Response.internalServerError(body: 'Root user not found');
    }

    if (root.passwordHash != Authenticator.hashPassword(current)) {
      return Response.forbidden('Invalid current password');
    }

    root.passwordHash = Authenticator.hashPassword(newPass);
    auth.usersBox.put(root);

    return Response.ok('Password changed');
  }
}
