import 'package:jigsaw/data/db/models/project_custom_fields.dart';
import 'package:jigsaw/data/db/models/projects.dart';
import 'package:jigsaw/data/db/models/task_field_custom_values.dart';
import 'package:jigsaw/data/db/models/tasks.dart';
import 'package:jigsaw/data/db/models/users.dart';
import 'package:jigsaw/objectbox.g.dart';

class ObjectBox {
  late final Store store;
  late final Box<Projects> projectsBox;
  late final Box<Tasks> taskBox;
  late final Box<TaskCustomFieldValues> taskCustomFieldValuesBox;
  late final Box<ProjectCustomFields> projectCustomFieldsBox;
  late final Box<Users> usersBox;

  ObjectBox._create(this.store) {
    projectsBox = Box<Projects>(store);
    taskBox = Box<Tasks>(store);
    taskCustomFieldValuesBox = Box<TaskCustomFieldValues>(store);
    projectCustomFieldsBox = Box<ProjectCustomFields>(store);
    usersBox = Box<Users>(store);
  }

  static Future<ObjectBox> create() async {
    final store = openStore();
    return ObjectBox._create(store);
  }
}
