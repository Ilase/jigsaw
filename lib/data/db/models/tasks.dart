import 'package:jigsaw/data/db/base_object.dart';
import 'package:jigsaw/data/db/models/projects.dart';
import 'package:jigsaw/data/db/models/task_field_custom_values.dart';
import 'package:objectbox/objectbox.dart';

/// Main entity of 'Project' which provides different things
@Entity()
class Tasks extends BaseObject {
  @Id()
  int id = 0;

  String title;
  String? body;

  final project = ToOne<Projects>();

  @Backlink()
  final customValues = ToMany<TaskCustomFieldValues>();

  Tasks({this.id = 0, required this.title, this.body});
}
