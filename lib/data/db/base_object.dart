import 'package:json_annotation/json_annotation.dart';
import 'package:objectbox/objectbox.dart';

/// Base object for entity who can be archived and deleted
@JsonSerializable()
abstract class BaseObject {
  @Property(type: PropertyType.date)
  final DateTime createDate = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? updateDate;

  @Property(type: PropertyType.date)
  DateTime? deleteDate;

  bool isArchived = false;
  bool isDeleted = false;

  //Base functions for "Soft Delete"

  void markUpdated() {
    updateDate = DateTime.now();
  }

  void markDeleted() {
    isDeleted = true;
    updateDate = DateTime.now();
  }

  void changeArchivedValue() {
    isArchived = !isArchived;
    updateDate = DateTime.now();
  }
}
