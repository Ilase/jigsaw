import 'package:jigsaw/data/db/models/users.dart';
import 'package:jigsaw/domain/api/jwt/jwt_auth.dart';
import 'package:jigsaw/objectbox.g.dart';

import 'models/project_custom_fields.dart';
import 'models/projects.dart';
import 'models/roles.dart';
import 'models/task_field_custom_values.dart';
import 'models/tasks.dart';

class ObjectBox {
  static late final ObjectBox _instance;

  static ObjectBox get instance => _instance;

  final Store store;
  final Box<Projects> projectsBox;
  final Box<Tasks> taskBox;
  final Box<TaskCustomFieldValues> taskCustomFieldValuesBox;
  final Box<ProjectCustomFields> projectCustomFieldsBox;
  final Box<Users> usersBox;
  late final Box<Roles> rolesBox;

  ObjectBox._create(this.store)
    : projectsBox = Box<Projects>(store),
      taskBox = Box<Tasks>(store),
      taskCustomFieldValuesBox = Box<TaskCustomFieldValues>(store),
      projectCustomFieldsBox = Box<ProjectCustomFields>(store),
      usersBox = Box<Users>(store),
      rolesBox = Box<Roles>(store);

  static Future<void> create() async {
    final store = openStore();
    _instance = ObjectBox._create(store);
    _instance._initRoles(); // in the start create roles
    _instance._initRootUser(); // in the start create root
  }

  void _initRoles() {
    final existing = rolesBox.getAll().map((r) => r.name).toSet();
    final requiredRoles = {'admin', 'worker', 'viewer'};

    for (final role in requiredRoles.difference(existing)) {
      rolesBox.put(Roles(name: role));
      print('✅ Role "$role" created');
    }
  }

  void _initRootUser() {
    final adminRole =
        rolesBox.query(Roles_.name.equals('admin')).build().findFirst();
    if (adminRole == null) {
      print(
        '❌ Role "admin" not found. Make sure _initRoles() is called first.',
      );
      return;
    }
    final existing =
        usersBox.query(Users_.nickname.equals('root')).build().findFirst();
    if (existing == null) {
      final rootUser = Users(
        nickname: 'root',
        passwordHash: Authenticator.hashPassword('root'),
        fName: 'Super',
        lName: 'User',
      )..role.target = adminRole;
      usersBox.put(rootUser);
      print("✅ Root user created");
    }
  }
}
