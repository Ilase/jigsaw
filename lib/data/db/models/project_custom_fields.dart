// ignore: unused_import
import 'package:jigsaw/data/db/field_type.dart';
import 'package:jigsaw/data/db/models/projects.dart';
import 'package:objectbox/objectbox.dart';

/// Entity for set custom fields to every 'Task' in 'Project'
@Entity()
class ProjectCustomFields {
  @Id()
  int id = 0;

  String name;
  String? description;

  //@Property(type: PropertyType.byte)
  String fieldType;

  final project = ToOne<Projects>();

  ProjectCustomFields({
    this.id = 0,
    required this.name,
    this.description,
    this.fieldType = "never",
  });

  // factory ProjectCustomFields.fromJson(Map<String, dynamic> json) =>
  //     _$ProjectCustomFieldsFromJson(json);
  //
  // Map<String, dynamic> toJson() => _$ProjectCustomFieldsToJson(this);
}
