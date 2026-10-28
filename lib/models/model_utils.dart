import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

int toInt(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

String toStr(dynamic v, [String fallback = '']) =>
    v is String ? v : fallback;

List<String> toStringList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];
