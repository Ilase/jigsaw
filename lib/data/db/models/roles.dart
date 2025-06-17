import 'package:objectbox/objectbox.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:jigsaw/data/db/base_object.dart';

part 'roles.g.dart';

@JsonSerializable()
@Entity()
class Roles extends BaseObject {
  @Id()
  int id = 0;

  String name;

  Roles({this.id = 0, required this.name});

  factory Roles.fromJson(Map<String, dynamic> json) => _$RolesFromJson(json);

  Map<String, dynamic> toJson() => _$RolesToJson(this);
}
