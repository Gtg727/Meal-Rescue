import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/inventory.dart';
import 'model_utils.dart';

class DonationModel {
  const DonationModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    this.organizationName = '',
    required this.title,
    required this.description,
    required this.category,
    required this.totalPortions,
    this.reservedPortions = 0,
    this.pendingPortions = 0,
    this.completedPortions = 0,
    required this.preparedAt,
    required this.pickupDeadline,
    required this.pickupAddress,
    this.latitude,
    this.longitude,
    this.imageUrl = '',
    this.allergens = const [],
    this.dietaryTags = const [],
    this.storageInstructions = '',
    this.safetyConfirmed = false,
    this.status = DonationStatus.draft,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String organizationName;
  final String title;
  final String description;
  final String category;
  final int totalPortions;

  /// Portions in ACCEPTED reservations that are not collected yet.
  final int reservedPortions;

  /// Portions in PENDING requests (not yet approved by the provider).
  final int pendingPortions;

  /// Portions already collected.
  final int completedPortions;
  final DateTime preparedAt;
  final DateTime pickupDeadline;
  final String pickupAddress;
  final double? latitude;
  final double? longitude;
  /// Food photo: a compressed `data:image/...;base64,` URI stored in the
  /// listing document (no Firebase Storage), or an http(s) URL. Empty = none.
  final String imageUrl;
  final List<String> allergens;
  final List<String> dietaryTags;
  final String storageInstructions;
  final bool safetyConfirmed;

  /// Stored status: draft | available | completed | expired | cancelled.
  /// "reserved" is derived (see [effectiveStatus]).
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DonationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final now = DateTime.now();
    return DonationModel(
      id: doc.id,
      providerId: toStr(d['providerId']),
      providerName: toStr(d['providerName']),
      organizationName: toStr(d['organizationName']),
      title: toStr(d['title']),
      description: toStr(d['description']),
      category: toStr(d['category'], 'Other'),
      totalPortions: toInt(d['totalPortions']),
      reservedPortions: toInt(d['reservedPortions']),
      pendingPortions: toInt(d['pendingPortions']),
      completedPortions: toInt(d['completedPortions']),
      preparedAt: toDate(d['preparedAt']) ?? now,
      pickupDeadline: toDate(d['pickupDeadline']) ?? now,
      pickupAddress: toStr(d['pickupAddress']),
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      imageUrl: toStr(d['imageUrl']),
      allergens: toStringList(d['allergens']),
      dietaryTags: toStringList(d['dietaryTags']),
      storageInstructions: toStr(d['storageInstructions']),
      safetyConfirmed: d['safetyConfirmed'] == true,
      status: toStr(d['status'], DonationStatus.draft),
      createdAt: toDate(d['createdAt']),
      updatedAt: toDate(d['updatedAt']),
    );
  }

  /// Portions a NEW request can still claim.
  int get reservablePortions => reservablePortionsOf(this);

  bool get isExpired => pickupDeadline.isBefore(DateTime.now());

  /// Status shown to users: applies the deadline and derives "reserved".
  String get effectiveStatus {
    if (status == DonationStatus.draft ||
        status == DonationStatus.cancelled ||
        status == DonationStatus.completed) {
      return status;
    }
    if (status == DonationStatus.expired || isExpired) {
      return DonationStatus.expired;
    }
    if (reservablePortions == 0 && (reservedPortions + pendingPortions) > 0) {
      return DonationStatus.reserved;
    }
    return status;
  }

  bool get isActive =>
      effectiveStatus == DonationStatus.available ||
      effectiveStatus == DonationStatus.reserved;

  /// Only published, unexpired listings with portions left can be reserved.
  bool get canReserve =>
      effectiveStatus == DonationStatus.available && reservablePortions > 0;

  bool get isEditable =>
      status == DonationStatus.draft ||
      (status == DonationStatus.available && !isExpired);

  bool get hasActiveReservations => reservedPortions + pendingPortions > 0;

  /// Name shown to receivers.
  String get providerLabel =>
      organizationName.isNotEmpty ? organizationName : providerName;

  Map<String, dynamic> toCreateMap() => {
        'providerId': providerId,
        'providerName': providerName,
        'organizationName': organizationName,
        'title': title,
        'description': description,
        'category': category,
        'totalPortions': totalPortions,
        'reservedPortions': 0,
        'pendingPortions': 0,
        'completedPortions': 0,
        'preparedAt': Timestamp.fromDate(preparedAt),
        'pickupDeadline': Timestamp.fromDate(pickupDeadline),
        'pickupAddress': pickupAddress,
        'latitude': latitude,
        'longitude': longitude,
        'imageUrl': imageUrl,
        'allergens': allergens,
        'dietaryTags': dietaryTags,
        'storageInstructions': storageInstructions,
        'safetyConfirmed': safetyConfirmed,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Editable fields only. Counters are never touched by an edit.
  Map<String, dynamic> toUpdateMap({required String status}) =>
      {
        'title': title,
        'description': description,
        'category': category,
        'totalPortions': totalPortions,
        'preparedAt': Timestamp.fromDate(preparedAt),
        'pickupDeadline': Timestamp.fromDate(pickupDeadline),
        'pickupAddress': pickupAddress,
        'imageUrl': imageUrl,
        'allergens': allergens,
        'dietaryTags': dietaryTags,
        'storageInstructions': storageInstructions,
        'safetyConfirmed': safetyConfirmed,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// Kept as a top-level function so inventory.dart stays free of model imports.
int reservablePortionsOf(DonationModel d) => reservablePortions(
      total: d.totalPortions,
      reserved: d.reservedPortions,
      completed: d.completedPortions,
      pending: d.pendingPortions,
    );
