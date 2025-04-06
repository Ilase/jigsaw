import 'package:jigsaw/data/db/base_object.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Users extends BaseObject {
  @Id()
  int id = 0;

  Users({this.id = 0});
}
