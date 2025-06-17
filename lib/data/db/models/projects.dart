import 'package:jigsaw/data/db/base_object.dart';
import 'package:jigsaw/data/db/models/project_custom_fields.dart';
import 'package:jigsaw/data/db/models/tasks.dart';
import 'package:jigsaw/data/db/models/users.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:objectbox/objectbox.dart';

part 'projects.g.dart';

/// Project entity
@JsonSerializable()
@Entity()
class Projects extends BaseObject {
  @Id()
  int id = 0;

  //General info
  String title;
  String description;

  // @Property(type: PropertyType.string)
  String readMe;

  int ownerId;

  /// Contains Tasks
  @Backlink()
  final tasks = ToMany<Tasks>();

  //
  @Backlink('collaboratedProjects')
  final ToMany<Users> collaborators = ToMany<Users>();

  /// Contains ProjectCustomFields
  final customFields = ToMany<ProjectCustomFields>();

  Projects({
    this.id = 0,
    required this.title,
    required this.description,
    required this.readMe,
    required this.ownerId,
  });

  factory Projects.fromJson(Map<String, dynamic> json) =>
      _$ProjectsFromJson(json);

  Map<String, dynamic> toJson() => _$ProjectsToJson(this);
}
