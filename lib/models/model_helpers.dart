import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? timestampToDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  return value as DateTime?;
}
