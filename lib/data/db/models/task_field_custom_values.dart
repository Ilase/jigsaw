import 'package:jigsaw/data/db/models/project_custom_fields.dart';
import 'package:jigsaw/data/db/models/tasks.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:objectbox/objectbox.dart';

part 'task_field_custom_values.g.dart';

@Entity()
@JsonSerializable()
class TaskCustomFieldValues {
  @Id()
  int id = 0;

  //ignore:prefer_typing_uninitialized_variables
  var value;
  final task = ToOne<Tasks>();
  final field = ToOne<ProjectCustomFields>();

  TaskCustomFieldValues({this.id = 0});

  factory TaskCustomFieldValues.fromJson(Map<String, dynamic> json) =>
      _$TaskCustomFieldValuesFromJson(json);

  Map<String, dynamic> toJson() => _$TaskCustomFieldValuesToJson(this);
}
