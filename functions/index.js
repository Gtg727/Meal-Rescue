// Optional (P1): informational push notifications for reservation events.
// The Firestore status stays authoritative; a notification is only a hint.
// Requires the Blaze plan to deploy.

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

async function notify(uid, title, body, data = {}) {
  const snap = await admin.firestore().collection('users').doc(uid).get();
  const token = snap.exists ? snap.data().fcmToken : null;
  if (!token) return;
  try {
    await admin.messaging().send({ token, notification: { title, body }, data });
  } catch (err) {
    console.warn('FCM send failed for', uid, err.code || err.message);
  }
}

// Receiver requested food -> tell the provider.
exports.onReservationCreated = onDocumentCreated('reservations/{id}', async (event) => {
  const r = event.data && event.data.data();
  if (!r) return;
  await notify(
    r.providerId,
    'New reservation request',
    `${r.receiverName} requested ${r.requestedPortions} portion(s) of ${r.donationTitle}.`,
    { reservationId: event.params.id },
  );
});

// Status changes -> tell the other party.
exports.onReservationUpdated = onDocumentUpdated('reservations/{id}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  const data = { reservationId: event.params.id };

  if (before.status !== after.status) {
    const t = after.donationTitle;
    switch (after.status) {
      case 'accepted':
        return notify(after.receiverId, 'Reservation accepted', `Pick up ${t} before the deadline.`, data);
      case 'rejected':
        return notify(after.receiverId, 'Reservation declined', `Your request for ${t} was declined.`, data);
      case 'cancelled':
        // Notify whichever side did not cancel (best effort: tell both).
        await notify(after.providerId, 'Reservation cancelled', `A reservation for ${t} was cancelled.`, data);
        return notify(after.receiverId, 'Reservation cancelled', `Your reservation for ${t} was cancelled.`, data);
      case 'completed':
        return notify(after.receiverId, 'Pickup completed', `Thanks for rescuing food: ${t}.`, data);
      default:
        return;
    }
  }

  if (!before.receiverConfirmed && after.receiverConfirmed) {
    await notify(after.providerId, 'Collection confirmed', `${after.receiverName} says they collected ${after.donationTitle}. Please confirm the handover.`, data);
  }
});
