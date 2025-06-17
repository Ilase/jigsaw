import 'package:jigsaw/data/db/base_object.dart';
import 'package:jigsaw/data/db/models/projects.dart';
import 'package:jigsaw/data/db/models/task_field_custom_values.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:objectbox/objectbox.dart';

part 'tasks.g.dart';

/// Main entity of 'Project' which provides different things
@Entity()
@JsonSerializable()
class Tasks extends BaseObject {
  @Id()
  int id = 0;

  String title;
  String? body;
  String? description;
  String status;

  final project = ToOne<Projects>();

  @Backlink()
  final customValues = ToMany<TaskCustomFieldValues>();

  Tasks({
    this.id = 0,
    required this.title,
    this.body,
    this.status = 'todo',
    this.description,
  });

  factory Tasks.fromJson(Map<String, dynamic> json) => _$TasksFromJson(json);

  Map<String, dynamic> toJson() => _$TasksToJson(this);
}
