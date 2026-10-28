import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import 'model_utils.dart';

class ReservationModel {
  const ReservationModel({
    required this.id,
    required this.donationId,
    required this.donationTitle,
    required this.pickupAddress,
    required this.pickupDeadline,
    required this.providerId,
    required this.providerName,
    this.providerPhone = '',
    required this.receiverId,
    required this.receiverName,
    this.receiverOrganization = '',
    this.receiverPhone = '',
    required this.requestedPortions,
    this.collectedPortions,
    this.status = ReservationStatus.pending,
    this.receiverConfirmed = false,
    this.providerConfirmed = false,
    this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.updatedAt,
  });

  final String id;
  final String donationId;
  final String donationTitle;
  final String pickupAddress;
  final DateTime pickupDeadline;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final String receiverId;
  final String receiverName;
  final String receiverOrganization;
  final String receiverPhone;
  final int requestedPortions;

  /// Portions actually handed over (set when completed).
  final int? collectedPortions;
  final String status;
  final bool receiverConfirmed;
  final bool providerConfirmed;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  factory ReservationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return ReservationModel(
      id: doc.id,
      donationId: toStr(d['donationId']),
      donationTitle: toStr(d['donationTitle']),
      pickupAddress: toStr(d['pickupAddress']),
      pickupDeadline: toDate(d['pickupDeadline']) ?? DateTime.now(),
      providerId: toStr(d['providerId']),
      providerName: toStr(d['providerName']),
      providerPhone: toStr(d['providerPhone']),
      receiverId: toStr(d['receiverId']),
      receiverName: toStr(d['receiverName']),
      receiverOrganization: toStr(d['receiverOrganization']),
      receiverPhone: toStr(d['receiverPhone']),
      requestedPortions: toInt(d['requestedPortions']),
      collectedPortions:
          d['collectedPortions'] == null ? null : toInt(d['collectedPortions']),
      status: toStr(d['status'], ReservationStatus.pending),
      receiverConfirmed: d['receiverConfirmed'] == true,
      providerConfirmed: d['providerConfirmed'] == true,
      createdAt: toDate(d['createdAt']),
      acceptedAt: toDate(d['acceptedAt']),
      completedAt: toDate(d['completedAt']),
      updatedAt: toDate(d['updatedAt']),
    );
  }

  bool get isActive => ReservationStatus.active.contains(status);

  /// Status shown to users. A pending/accepted reservation whose pickup
  /// deadline passed without collection is shown as expired even before the
  /// provider's clean-up pass writes that status.
  String get effectiveStatus {
    if (isActive &&
        !receiverConfirmed &&
        pickupDeadline.isBefore(DateTime.now())) {
      return ReservationStatus.expired;
    }
    return status;
  }

  bool get isActiveEffective => ReservationStatus.active.contains(effectiveStatus);

  /// Portions counted towards impact once completed.
  int get portionsCollected => collectedPortions ?? requestedPortions;

  /// When the record last changed (for "recent activity").
  DateTime get lastActivity =>
      updatedAt ?? completedAt ?? acceptedAt ?? createdAt ?? pickupDeadline;

  String get receiverLabel =>
      receiverOrganization.isNotEmpty ? receiverOrganization : receiverName;
}
