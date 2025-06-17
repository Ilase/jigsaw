import 'dart:convert';

import 'package:jigsaw/data/db/db_service.dart';
import 'package:jigsaw/data/db/models/projects.dart';
import 'package:jigsaw/data/db/models/roles.dart';
import 'package:jigsaw/data/db/models/tasks.dart';
import 'package:jigsaw/data/db/models/users.dart';
import 'package:jigsaw/domain/api/jwt/jwt_auth.dart';
import 'package:jigsaw/objectbox.g.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class ApiService {
  Authenticator auth;
  final Router router;
  late final Handler handler;

  ApiService({required this.auth}) : router = Router() {
    _setupRoutes();
    // handler = const Pipeline()
    //     .addMiddleware(
    //       logRequests(
    //         logger: (line, f) {
    //           print("$line || isError?: ${f.toString()}");
    //         },
    //       ),
    //     )
    //     ///JWT middleware
    //     .addMiddleware(
    //       auth.verifyJWT(
    //         excludedPaths: ['api/v1', 'api/v1/login', 'api/v1/refresh'],
    //       ),
    //     )
    //     .addHandler(_router.call);

    // _router.mount('', handler);
    // _router.mount('', _router.call);
  }

  bool _isAdmin(Request request) {
    final role = request.context['role'];
    print('🔍 Checking role: $role'); // ← проверь, что там реально "admin"
    return request.context['role'] == 'admin';
  }

  void _setupRoutes() {
    router.get('/check', _check);

    ///not saved
    router.post('/login', _login);

    /// saved routes
    router.get('/users', _getAllUsers);
    router.get('/users/me', _getCurrentUser);
    router.post('/users', _createUser);
    router.delete('/users/<nickname>', _deleteUser);
    router.patch('/users/root/password', _changeRootPass);
    router.post('/projects', _createProject);
    router.post('/projects/<projectId>/add-user', _addUserToProject);
    router.post('/projects/<projectId>/add-users', _addUsersToProject);
    router.get('/projects', _getUserProjects);
    router.delete('/projects/<id>', _deleteProject);
    router.patch('/projects/<id>', _updateProject);
    router.get('/projects/<id>', _getProjectById);
    router.get('/projects/<id>/tasks', _getProjectTasks);
    router.post('/refresh', _refreshToken);

    ///
    // router.get('/projects/<id>/tasks', _getProjectTasks);
    ///
    router.post('/projects/<id>/tasks', _createTask);
    router.delete('/tasks/<taskId>', _deleteTask);
    router.patch('/tasks/<taskId>', _updateTask);
  }

  Future<Response> _check(Request request) async {
    return Response.ok(jsonEncode({"ok": "ok"}));
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

    final role = user.role.target?.name ?? 'unknown';

    final accessToken = auth.generateAccessToken(user.nickname, role);
    final refreshToken = auth.generateRefreshToken(user.nickname);

    return Response.ok(
      jsonEncode({
        "accessToken": accessToken,
        "refreshToken": refreshToken,
        "expiresIn": 900,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _getAllUsers(Request request) async {
    final users =
        auth.usersBox
            .getAll()
            .map(
              (u) => {
                'id': u.id,
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
        'id': user.id,
        'nickname': user.nickname,
        'role': user.role.target?.name,
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
    final email = data['email'];
    if (nickname == null || password == null || role == null) {
      return Response(400, body: 'Missing required fields');
    }
    if (email == null) {
      return Response(409, body: 'Email is required');
    }
    final duplicateEmail =
        auth.usersBox.query(Users_.email.equals(email)).build().findFirst();

    if (duplicateEmail != null) {
      return Response(409, body: 'Email already in use');
    }

    final existing =
        auth.usersBox
            .query(Users_.nickname.equals(nickname))
            .build()
            .findFirst();

    if (existing != null) {
      return Response(409, body: 'User already exists');
    }

    ///TODO: fix
    if (role == null) {
      return Response(400, body: 'Invalid role');
    }
    final user = Users(
      nickname: nickname,
      passwordHash: Authenticator.hashPassword(password),
      fName: fName,
      lName: lName,
      email: email,
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

  Future<Response> _createProject(Request request) async {
    final role = request.context['role'] as String?;
    final username = request.context['username'] as String?;

    if (role != 'admin' && role != 'worker') {
      return Response.forbidden('Only admin or worker can create projects');
    }

    final data = jsonDecode(await request.readAsString());

    final title = data['title'] as String?;
    if (title == null || title.trim().isEmpty) {
      return Response(400, body: 'Missing or empty title');
    }
    if (username == null) {
      return Response.forbidden('Unauthorized: no username in context');
    }
    final user =
        ObjectBox.instance.usersBox
            .query(Users_.nickname.equals(username))
            .build()
            .findFirst();

    if (user == null) {
      return Response.internalServerError(body: 'User not found');
    }

    final project = Projects(
      title: title.trim(),
      description: data['description'] ?? '',
      readMe: data['readMe'] ?? '',
      ownerId: user.id,
    )..collaborators.add(user);

    ObjectBox.instance.projectsBox.put(project);

    return Response.ok(
      jsonEncode({
        'message': 'Project created',
        'project': {
          'id': project.id,
          'title': project.title,
          'ownerId': user.id,
        },
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _getUserProjects(Request request) async {
    final role = request.context['role'] as String?;
    final username = request.context['username'] as String?;

    if (username == null) {
      return Response.forbidden('Unauthorized: no username in context');
    }

    final user =
        ObjectBox.instance.usersBox
            .query(Users_.nickname.equals(username))
            .build()
            .findFirst();

    if (user == null) {
      return Response.internalServerError(body: 'User not found');
    }

    final projects =
        role == 'admin'
            ? ObjectBox.instance.projectsBox.getAll()
            : user.collaboratedProjects;

    final result =
        projects.map((p) {
          // Подсчёт количества задач в проекте
          final taskCount = p.tasks.length;

          return {
            'id': p.id,
            'title': p.title,
            'description': p.description,
            'readMe': p.readMe,
            'owner':
                ObjectBox.instance.usersBox.get(p.ownerId)?.nickname ??
                'unknown',
            'collaborators': p.collaborators.map((u) => u.nickname).toList(),
            'taskCount': taskCount, // Добавлено поле с количеством задач
          };
        }).toList();

    return Response.ok(
      jsonEncode({'projects': result}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _addUserToProject(Request request, String projectId) async {
    final role = request.context['role'] as String?;
    if (role != 'admin' && role != 'worker') {
      return Response.forbidden('Only admin or worker can modify projects');
    }

    final data = jsonDecode(await request.readAsString());
    final nicknameToAdd = data['nickname'] as String?;

    if (nicknameToAdd == null) {
      return Response(400, body: 'Missing nickname');
    }

    final project = ObjectBox.instance.projectsBox.get(int.parse(projectId));
    if (project == null) {
      return Response.notFound('Project not found');
    }

    final userToAdd =
        ObjectBox.instance.usersBox
            .query(Users_.nickname.equals(nicknameToAdd))
            .build()
            .findFirst();

    if (userToAdd == null) {
      return Response.notFound('User not found');
    }

    if (project.collaborators.any((u) => u.id == userToAdd.id)) {
      return Response(409, body: 'User already added to project');
    }

    project.collaborators.add(userToAdd);
    ObjectBox.instance.projectsBox.put(project);

    return Response.ok('User added to project');
  }

  Future<Response> _addUsersToProject(Request request, String projectId) async {
    final role = request.context['role'] as String?;
    if (role != 'admin' && role != 'worker') {
      return Response.forbidden('Only admin or worker can modify projects');
    }

    final data = jsonDecode(await request.readAsString());
    final nicknames = data['nicknames'] as List<dynamic>?;

    if (nicknames == null || nicknames.isEmpty) {
      return Response(400, body: 'Missing or empty nicknames list');
    }

    final project = ObjectBox.instance.projectsBox.get(int.parse(projectId));
    if (project == null) {
      return Response.notFound('Project not found');
    }

    final usersToAdd = <Users>[];
    final notFound = <String>[];
    final alreadyAdded = <String>[];

    for (final nickname in nicknames) {
      final user =
          ObjectBox.instance.usersBox
              .query(Users_.nickname.equals(nickname as String))
              .build()
              .findFirst();

      if (user == null) {
        notFound.add(nickname);
        continue;
      }

      if (project.collaborators.any((u) => u.id == user.id)) {
        alreadyAdded.add(nickname);
        continue;
      }

      usersToAdd.add(user);
    }

    if (usersToAdd.isNotEmpty) {
      project.collaborators.addAll(usersToAdd);
      ObjectBox.instance.projectsBox.put(project);
    }

    final response = {
      'added': usersToAdd.map((u) => u.nickname).toList(),
      'not_found': notFound,
      'already_added': alreadyAdded,
    };

    return Response.ok(
      jsonEncode(response),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _getProjectById(Request request, String id) async {
    final role = request.context['role'] as String?;
    final username = request.context['username'] as String?;

    final projectId = int.tryParse(id);
    if (projectId == null) {
      return Response(400, body: 'Invalid project ID');
    }

    final project = ObjectBox.instance.projectsBox.get(projectId);
    if (project == null) {
      return Response.notFound('Project not found');
    }

    if (username == null) {
      return Response(409, body: "Internal error. Project not found");
    }

    final user =
        ObjectBox.instance.usersBox
            .query(Users_.nickname.equals(username))
            .build()
            .findFirst();

    if (user == null) {
      return Response.internalServerError(body: 'User not found');
    }

    final isAdmin = role == 'admin';
    final isCollaborator = project.collaborators.any((u) => u.id == user.id);

    if (!isAdmin && !isCollaborator) {
      return Response.forbidden('Access denied to this project');
    }

    // Формируем задачи
    final tasks =
        project.tasks
            .map((t) => {'id': t.id, 'title': t.title, 'body': t.body})
            .toList();

    final collaborators =
        project.collaborators
            .map(
              (u) => {
                'nickname': u.nickname,
                'email': u.email,
                'fName': u.fName,
                'lName': u.lName,
                'role': u.role.target?.name,
              },
            )
            .toList();

    final response = {
      'id': project.id,
      'title': project.title,
      'description': project.description,
      'readMe': project.readMe,
      'ownerId': project.ownerId,
      'collaborators': collaborators,
      'tasks': tasks,
    };

    return Response.ok(
      jsonEncode(response),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _deleteProject(Request request, String id) async {
    final role = request.context['role'] as String?;
    final username = request.context['username'] as String?;

    if (username == null) {
      return Response.forbidden('Unauthorized: no username in context');
    }

    final user =
        ObjectBox.instance.usersBox
            .query(Users_.nickname.equals(username))
            .build()
            .findFirst();

    if (user == null) {
      return Response.internalServerError(body: 'User not found');
    }

    final projectId = int.tryParse(id);
    if (projectId == null) {
      return Response(400, body: 'Invalid project ID');
    }

    final project = ObjectBox.instance.projectsBox.get(projectId);
    if (project == null) {
      return Response.notFound('Project not found');
    }

    final isOwner = project.ownerId == user.id;
    final isAdmin = role == 'admin';

    if (!isAdmin && !isOwner) {
      return Response.forbidden(
        'Only admins or project owners can delete this project',
      );
    }

    // ❌ Удалим задачи
    for (final task in project.tasks) {
      ObjectBox.instance.taskBox.remove(task.id);
    }

    // ❌ Удалим кастомные поля
    for (final field in project.customFields) {
      ObjectBox.instance.projectCustomFieldsBox.remove(field.id);
    }

    // ❌ Удалим сам проект
    ObjectBox.instance.projectsBox.remove(projectId);

    return Response.ok(
      jsonEncode({
        'message': 'Project deleted along with related tasks and fields',
        'projectId': projectId,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _getProjectTasks(Request request, String id) async {
    final role = request.context['role'] as String?;
    final username = request.context['username'] as String?;

    final projectId = int.tryParse(id);
    if (projectId == null) {
      return Response(400, body: 'Invalid project ID');
    }

    final project = ObjectBox.instance.projectsBox.get(projectId);
    if (project == null) return Response.notFound('Project not found');

    if (username == null) {
      return Response.internalServerError(body: 'Username not found');
    }

    final user =
        ObjectBox.instance.usersBox
            .query(Users_.nickname.equals(username))
            .build()
            .findFirst();

    if (user == null) {
      return Response.internalServerError(body: 'User not found');
    }

    final isAdmin = role == 'admin';
    final isCollaborator = project.collaborators.any((u) => u.id == user.id);
    if (!isAdmin && !isCollaborator) {
      return Response.forbidden('Access denied to this project');
    }

    // Query params
    final query = request.url.queryParameters;
    final search = query['search']?.toLowerCase() ?? '';
    final sort = query['sort'] ?? 'id_asc';

    var tasks =
        project.tasks.where((t) {
          if (search.isEmpty) return true;
          return fuzzyMatch(t.title, search) || fuzzyMatch(t.body, search);
        }).toList();

    // Sort
    tasks.sort((a, b) {
      switch (sort) {
        case 'title_asc':
          return a.title.compareTo(b.title);
        case 'title_desc':
          return b.title.compareTo(a.title);
        case 'id_desc':
          return b.id.compareTo(a.id);
        case 'id_asc':
        default:
          return a.id.compareTo(b.id);
      }
    });

    return Response.ok(
      jsonEncode({
        'total': tasks.length,
        'tasks':
            tasks
                .map(
                  (t) => {
                    'id': t.id,
                    'title': t.title,
                    'description': t.description,
                    'body': t.body,
                    'status': t.status,
                  },
                )
                .toList(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _updateProject(Request request, String id) async {
    final username = request.context['username'] as String?;
    final role = request.context['role'] as String?;

    final project = ObjectBox.instance.projectsBox.get(int.parse(id));
    if (project == null) return Response.notFound('Project not found');

    final user =
        ObjectBox.instance.usersBox
            .query(Users_.nickname.equals(username!))
            .build()
            .findFirst();

    final isOwner = user?.id == project.ownerId;
    final isAdmin = role == 'admin';

    if (!isOwner && !isAdmin) {
      return Response.forbidden('Only owner or admin can edit project');
    }

    final data = jsonDecode(await request.readAsString());

    project.title = data['title'] ?? project.title;
    project.description = data['description'] ?? project.description;
    project.readMe = data['readMe'] ?? project.readMe;

    ObjectBox.instance.projectsBox.put(project);

    return Response.ok(
      jsonEncode({
        'message': 'Project updated',
        'project': {
          'id': project.id,
          'title': project.title,
          'description': project.description,
          'readMe': project.readMe,
        },
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _refreshToken(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final username = data['username'];
    final refreshToken = data['refreshToken'];

    if (username == null || refreshToken == null) {
      return Response(400, body: 'Missing fields');
    }

    final user =
        auth.usersBox
            .query(Users_.nickname.equals(username))
            .build()
            .findFirst();

    if (user == null || !auth.validateRefreshToken(username, refreshToken)) {
      return Response.unauthorized('Invalid refresh token');
    }

    final role = user.role.target?.name ?? 'unknown';
    final newAccessToken = auth.generateAccessToken(username, role);

    return Response.ok(
      jsonEncode({"accessToken": newAccessToken, "expiresIn": 900}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _createTaskForProject(Request request, String id) async {
    final role = request.context['role'] as String?;
    final username = request.context['username'] as String?;
    if (username == null) {
      return Response.forbidden('Unauthorized: no username in context');
    }

    final user =
        ObjectBox.instance.usersBox
            .query(Users_.nickname.equals(username))
            .build()
            .findFirst();

    if (user == null) {
      return Response.internalServerError(body: 'User not found');
    }

    final projectId = int.tryParse(id);
    if (projectId == null) {
      return Response(400, body: 'Invalid project ID');
    }

    final project = ObjectBox.instance.projectsBox.get(projectId);
    if (project == null) {
      return Response.notFound('Project not found');
    }

    // Проверка доступа
    final isAdmin = role == 'admin';
    final isCollaborator = project.collaborators.any((u) => u.id == user.id);
    if (!isAdmin && !isCollaborator) {
      return Response.forbidden(
        'Only admins or collaborators can create tasks',
      );
    }

    // Читаем тело запроса
    final bodyStr = await request.readAsString();
    final data = jsonDecode(bodyStr);

    final title = data['title']?.toString().trim();
    final taskBody = data['body']?.toString().trim();

    if (title == null || title.isEmpty) {
      return Response(400, body: 'Missing or empty title');
    }

    final task = Tasks(title: title, body: taskBody);
    task.project.target = project;

    ObjectBox.instance.taskBox.put(task);

    return Response.ok(
      jsonEncode({
        'message': 'Task created',
        'task': {
          'id': task.id,
          'title': task.title,
          'body': task.body,
          'projectId': project.id,
        },
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _createTask(Request request, String id) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final projectId = int.tryParse(id);
    if (projectId == null) {
      return Response.badRequest(body: 'Некорректный ID проекта');
    }

    final project = auth.projectsBox.get(projectId);
    if (project == null) {
      return Response.notFound('Проект не найден');
    }

    final task = Tasks(
      title: data['title'],
      body: data['body'] ?? '',
      status: data['status'] ?? 'todo',
      description: data['description'] ?? '',
    );
    task.project.target = project;
    print('Создание задачи: title=${task.title}, status=${task.status}');
    auth.tasksBox.put(task);

    return Response.ok(
      jsonEncode({'id': task.id}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _deleteTask(Request request, String taskId) async {
    final id = int.tryParse(taskId);
    if (id == null) return Response.badRequest(body: 'ID is incorrect');

    final success = auth.tasksBox.remove(id);
    if (!success) return Response.notFound('Task not found');

    return Response.ok('Deleted');
  }

  Future<Response> _updateTask(Request request, String taskId) async {
    final id = int.tryParse(taskId);
    if (id == null) return Response.badRequest(body: 'ID is incorrect');

    final task = auth.tasksBox.get(id);
    if (task == null) return Response.notFound('Task not found');

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (data.containsKey('title')) task.title = data['title'];
    if (data.containsKey('description')) task.description = data['description'];
    if (data.containsKey('status')) task.status = data['status'];
    if (data.containsKey('body')) task.body = data['body'];

    auth.tasksBox.put(task);

    return Response.ok(
      jsonEncode({'status': 'updated'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Future<Response> _updateTask(Request request, String taskId) async {
  //   // Try to parse the taskId to an integer
  //   final id = int.tryParse(taskId);
  //   if (id == null) return Response.badRequest(body: 'Invalid task ID');
  //
  //   // Fetch the task from the database using the task ID
  //   final task = auth.tasksBox.get(id);
  //   if (task == null) return Response.notFound('Task not found');
  //
  //   // Read the request body to get updated task information
  //   final body = await request.readAsString();
  //   final data = jsonDecode(body) as Map<String, dynamic>;
  //
  //   // Check if the incoming request has the necessary task fields to update
  //   if (data.containsKey('title')) {
  //     task.title = data['title'];
  //   }
  //   if (data.containsKey('body')) {
  //     task.body = data['body'];
  //   }
  //   if (data.containsKey('status')) {
  //     task.status = data['status'];
  //   }
  //
  //   // Optionally, you can add validation here to check the status, title, etc.
  //   // For example, check if the new status is valid:
  //   if (task.status != 'todo' &&
  //       task.status != 'in_progress' &&
  //       task.status != 'done') {
  //     return Response(400, body: 'Invalid task status');
  //   }
  //
  //   // Save the updated task to the database
  //   auth.tasksBox.put(task);
  //
  //   // Return a success response with the updated task
  //   return Response.ok(
  //     jsonEncode({
  //       'status': 'updated',
  //       'task': {
  //         'id': task.id,
  //         'title': task.title,
  //         'body': task.body,
  //         'status': task.status,
  //       },
  //     }),
  //     headers: {'Content-Type': 'application/json'},
  //   );
  // }

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

  bool fuzzyMatch(String? source, String query) {
    if (source == null) return false;

    final cleanedSource = source.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final cleanedQuery = query.toLowerCase().trim();

    return cleanedSource.contains(cleanedQuery);
  }
}

Future<void> deleteProjectCascade(int projectId) async {
  final projectsBox = ObjectBox.instance.projectsBox;
  final taskBox = ObjectBox.instance.taskBox;
  final customFieldsBox = ObjectBox.instance.projectCustomFieldsBox;

  final project = projectsBox.get(projectId);
  if (project == null) return;

  // Удаляем связанные задачи
  for (final task in project.tasks) {
    taskBox.remove(task.id);
  }

  // Удаляем связанные кастомные поля
  for (final field in project.customFields) {
    customFieldsBox.remove(field.id);
  }

  // Удаляем сам проект
  projectsBox.remove(projectId);
}
