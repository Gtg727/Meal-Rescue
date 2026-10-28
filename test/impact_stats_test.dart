import 'package:flutter_test/flutter_test.dart';
import 'package:meal_rescue/core/constants/app_constants.dart';
import 'package:meal_rescue/models/donation_model.dart';
import 'package:meal_rescue/models/impact_stats.dart';
import 'package:meal_rescue/models/reservation_model.dart';

ReservationModel res(
  String id,
  String status, {
  int requested = 10,
  int? collected,
  String donationId = 'd1',
  String receiverId = 'r1',
}) =>
    ReservationModel(
      id: id,
      donationId: donationId,
      donationTitle: 'Rice',
      pickupAddress: 'Canteen',
      pickupDeadline: DateTime.now().add(const Duration(hours: 2)),
      providerId: 'p1',
      providerName: 'Canteen',
      receiverId: receiverId,
      receiverName: 'NGO',
      requestedPortions: requested,
      collectedPortions: collected,
      status: status,
      receiverConfirmed: status == ReservationStatus.completed,
      providerConfirmed: status == ReservationStatus.completed,
    );

DonationModel don(String id, String status, {int completed = 0}) => DonationModel(
      id: id,
      providerId: 'p1',
      providerName: 'Canteen',
      title: 'Rice',
      description: 'Vegetable rice',
      category: 'Cooked meals',
      totalPortions: 30,
      completedPortions: completed,
      preparedAt: DateTime.now().subtract(const Duration(hours: 1)),
      pickupDeadline: DateTime.now().add(const Duration(hours: 3)),
      pickupAddress: 'Canteen',
      status: status,
    );

void main() {
  test('spec example: 10 + 8 collected out of 30 = 18 redistributed', () {
    final stats = ImpactStats.compute(
      reservations: [
        res('a', ReservationStatus.completed, requested: 10),
        res('b', ReservationStatus.completed, requested: 8),
      ],
      donations: [don('d1', DonationStatus.available, completed: 18)],
    );
    expect(stats.portionsRedistributed, 18);
    expect(stats.pickupsCompleted, 2);
    // One collected pickup does not make the whole donation completed.
    expect(stats.completedDonations, 0);
    expect(stats.activeCount, 1);
  });

  test('partial pickup counts only collected portions', () {
    final stats = ImpactStats.compute(
      reservations: [res('a', ReservationStatus.completed, requested: 10, collected: 6)],
      donations: [don('d1', DonationStatus.completed, completed: 6)],
    );
    expect(stats.portionsRedistributed, 6);
    expect(stats.completedDonations, 1);
  });

  test('pending, rejected and cancelled reservations add no impact', () {
    final stats = ImpactStats.compute(
      reservations: [
        res('a', ReservationStatus.pending),
        res('b', ReservationStatus.rejected),
        res('c', ReservationStatus.cancelled),
      ],
      donations: [don('d1', DonationStatus.available)],
    );
    expect(stats.portionsRedistributed, 0);
    expect(stats.pickupsCompleted, 0);
  });

  test('receiver view: distinct donations and active reservations', () {
    final stats = ImpactStats.compute(reservations: [
      res('a', ReservationStatus.completed, donationId: 'd1'),
      res('b', ReservationStatus.completed, donationId: 'd1'),
      res('c', ReservationStatus.completed, donationId: 'd2'),
      res('d', ReservationStatus.accepted, donationId: 'd3'),
    ]);
    expect(stats.completedDonations, 2);
    expect(stats.pickupsCompleted, 3);
    expect(stats.activeCount, 1);
  });

  test('recent activity is limited and sorted newest first', () {
    final base = DateTime(2026, 1, 1);
    final list = [
      for (var i = 0; i < 12; i++)
        ReservationModel(
          id: '$i',
          donationId: 'd',
          donationTitle: 't',
          pickupAddress: 'a',
          pickupDeadline: base.add(const Duration(days: 30)),
          providerId: 'p',
          providerName: 'p',
          receiverId: 'r',
          receiverName: 'r',
          requestedPortions: 1,
          updatedAt: base.add(Duration(hours: i)),
        ),
    ];
    final recent = ImpactStats.recentActivity(list, limit: 5);
    expect(recent.length, 5);
    expect(recent.first.id, '11');
  });
}
