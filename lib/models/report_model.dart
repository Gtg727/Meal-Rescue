import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_utils.dart';

class ReportModel {
  const ReportModel({
    required this.id,
    required this.donationId,
    required this.donationTitle,
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    this.details = '',
    this.status = 'open',
    this.createdAt,
  });

  final String id;
  final String donationId;
  final String donationTitle;
  final String reporterId;
  final String reporterName;
  final String reason;
  final String details;

  /// open | resolved | dismissed
  final String status;
  final DateTime? createdAt;

  bool get isOpen => status == 'open';

  factory ReportModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return ReportModel(
      id: doc.id,
      donationId: toStr(d['donationId']),
      donationTitle: toStr(d['donationTitle']),
      reporterId: toStr(d['reporterId']),
      reporterName: toStr(d['reporterName']),
      reason: toStr(d['reason']),
      details: toStr(d['details']),
      status: toStr(d['status'], 'open'),
      createdAt: toDate(d['createdAt']),
    );
  }
}
