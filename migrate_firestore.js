const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

const userCollections = [
  'doctors',
  'deductions',
  'sales_orders',
  'incidental_coverage_forms',
  'coaching_forms'
];

const globalCollections = ['signatures'];

async function migrateUserSubcollections() {
  const userDocs = await db.collection('users').get();

  for (const userDoc of userDocs.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();

    // Create the user's document at flowdb/users/{userId}
    await db.collection('flowdb').collection('users').doc(userId).set(userData, { merge: true });

    for (const col of userCollections) {
      const subDocs = await db.collection(col).where('userId', '==', userId).get();
      for (const doc of subDocs.docs) {
        // CORRECT: users DOC, not COLLECTION
        await db.collection('flowdb')
          .collection('users')
          .doc(userId)
          .collection(col)
          .doc(doc.id)
          .set(doc.data(), { merge: true });

        console.log(`Copied ${col}/${doc.id} for user ${userId}`);
      }
    }
  }
}

// For global (non-user) collections like signatures
async function migrateGlobalCollections() {
  for (const col of globalCollections) {
    const docs = await db.collection(col).get();
    for (const doc of docs.docs) {
      await db.collection('flowdb').collection(col).doc(doc.id).set(doc.data(), { merge: true });
      console.log(`Copied global ${col}/${doc.id}`);
    }
  }
}

async function main() {
  await migrateUserSubcollections();
  await migrateGlobalCollections();
  console.log("Migration complete! Nothing deleted; all data COPIED to flowdb.");
}

main().then(() => process.exit(0)).catch(console.error);
