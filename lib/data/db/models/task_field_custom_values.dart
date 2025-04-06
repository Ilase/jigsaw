import 'package:jigsaw/data/db/models/project_custom_fields.dart';
import 'package:jigsaw/data/db/models/tasks.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class TaskCustomFieldValues {
  @Id()
  int id = 0;

  //ignore:prefer_typing_uninitialized_variables
  var value;
  final task = ToOne<Tasks>();
  final field = ToOne<ProjectCustomFields>();

  TaskCustomFieldValues({this.id = 0});
}
