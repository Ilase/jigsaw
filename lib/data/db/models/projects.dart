import 'package:jigsaw/data/db/base_object.dart';
import 'package:jigsaw/data/db/models/project_custom_fields.dart';
import 'package:jigsaw/data/db/models/tasks.dart';
import 'package:jigsaw/data/db/models/users.dart';
import 'package:objectbox/objectbox.dart';

/// Project entity
@Entity()
class Projects extends BaseObject {
  @Id()
  int id = 0;

  //General info
  String title;
  String description;
  String readMe;

  /// Contains Tasks
  @Backlink()
  final tasks = ToMany<Tasks>();

  //
  @Backlink()
  List<Users> collaborators = ToMany<Users>();

  /// Contains ProjectCustomFields
  final customFields = ToMany<ProjectCustomFields>();

  Projects({
    this.id = 0,
    required this.title,
    required this.description,
    required this.readMe,
  });
}
