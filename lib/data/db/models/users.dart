import 'package:jigsaw/data/db/base_object.dart';
import 'package:jigsaw/data/db/models/roles.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:objectbox/objectbox.dart';

part 'users.g.dart';

@JsonSerializable()
@Entity()
class Users extends BaseObject {
  @Id()
  int id = 0;

  String nickname;
  String? fName;
  String? lName;

  String passwordHash;

  final role = ToOne<Roles>();

  Users({
    this.id = 0,
    required this.nickname,
    required this.passwordHash,
    this.fName,
    this.lName,
  });

  factory Users.fromJson(Map<String, dynamic> json) => _$UsersFromJson(json);

  Map<String, dynamic> toJson() => _$UsersToJson(this);
}
