import 'package:objectbox/objectbox.dart';

@Entity()
class Roles {
  @Id()
  int id = 0;
  String role;

  Roles({this.id = 0, required this.role});

  @override
  String toString() {
    return role.toString();
  }
}
