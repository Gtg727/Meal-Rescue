// Creates demo accounts (2 providers, 2 receivers, 1 admin) for testing the
// multi-user workflow. Run once per Firebase project:
//
//   cd tool && npm install firebase-admin
//   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
//   node seed_demo_users.js
//
// The service account key comes from Firebase console -> Project settings ->
// Service accounts -> Generate new private key. Never commit that file.
// Set DEMO_PASSWORD in the environment before running this script.

const admin = require('firebase-admin');
const PASSWORD = process.env.DEMO_PASSWORD;
if (!PASSWORD) {
  throw new Error('Set DEMO_PASSWORD before running this script.');
}
admin.initializeApp({ credential: admin.credential.applicationDefault() });

const users = [
  { email: 'canteen@example.com', name: 'College Canteen', role: 'provider', org: 'College Canteen', phone: '9000000001', area: 'Main Block, College Campus' },
  { email: 'bakery@example.com', name: 'Sunrise Bakery', role: 'provider', org: 'Sunrise Bakery', phone: '9000000002', area: 'Market Road' },
  { email: 'ngo@example.com', name: 'Asha Rao', role: 'receiver', org: 'Hope Foundation (NGO)', phone: '9000000003', area: 'City Centre' },
  { email: 'volunteer@example.com', name: 'Ravi Kumar', role: 'receiver', org: '', phone: '9000000004', area: 'North Colony' },
  { email: 'admin@example.com', name: 'Platform Admin', role: 'admin', org: '', phone: '', area: '' },
];

(async () => {
  for (const u of users) {
    let uid;
    try {
      uid = (await admin.auth().getUserByEmail(u.email)).uid;
      console.log('exists ', u.email);
    } catch (_) {
      uid = (await admin.auth().createUser({ email: u.email, password: PASSWORD, displayName: u.name })).uid;
      console.log('created', u.email);
    }
    await admin.firestore().collection('users').doc(uid).set({
      fullName: u.name,
      email: u.email,
      phone: u.phone,
      role: u.role,
      organizationName: u.org,
      defaultPickupArea: u.area,
      isVerified: u.role !== 'receiver',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  console.log('Done. Sign in with any email above and the password you supplied.');
})().catch((e) => { console.error(e); process.exit(1); });
