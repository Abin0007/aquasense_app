const admin = require("firebase-admin");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");

admin.initializeApp();

/**
 * Listens for updates on user documents and performs a full deletion if a
 * 'deletionRequested' flag is set to true by a supervisor.
 * This function uses the v2 syntax for Cloud Functions for Firebase.
 */
exports.handleDeletionRequest = onDocumentUpdated("users/{userId}",
    async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const userIdToDelete = event.params.userId;

      // Check if the 'deletionRequested' flag has been newly set to true.
      if (afterData.deletionRequested !== true ||
    beforeData.deletionRequested === true) {
        console.log(
            `No action needed for user ${userIdToDelete}. ` +
        "Flag not set or already processed.",
        );
        return null;
      }

      console.log(`Deletion requested for user: ${userIdToDelete}. ` +
    "Starting deletion process...");

      try {
      // 1. Delete user from Firebase Authentication
        await admin.auth().deleteUser(userIdToDelete);
        console.log(`Successfully deleted auth user: ${userIdToDelete}`);

        // 2. Delete the user's document from Firestore
        const userDocRef = admin.firestore()
            .collection("users").doc(userIdToDelete);
        await userDocRef.delete();
        console.log(`Successfully deleted user document: ${userIdToDelete}`);

        // 3. Delete associated complaints
        const complaintsRef = admin.firestore().collection("complaints");
        const complaintsSnapshot = await complaintsRef
            .where("userId", "==", userIdToDelete).get();
        if (!complaintsSnapshot.empty) {
          const batch = admin.firestore().batch();
          complaintsSnapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
          });
          await batch.commit();
          console.log(
              `Deleted ${complaintsSnapshot.size} complaints for user ` +
          `${userIdToDelete}`,
          );
        }

        // 4. Delete other user-specific data
        const connectionRequestsRef = admin.firestore()
            .collection("connection_requests");
        const requestsSnapshot = await connectionRequestsRef
            .where("userId", "==", userIdToDelete).get();

        if (!requestsSnapshot.empty) {
          const requestBatch = admin.firestore().batch();
          requestsSnapshot.docs.forEach((doc) => {
            requestBatch.delete(doc.ref);
          });
          await requestBatch.commit();
          console.log(
              `Deleted ${requestsSnapshot.size} connection requests for user ` +
          `${userIdToDelete}`,
          );
        }

        if (afterData.phoneNumber) {
          await admin.firestore()
              .collection("phoneNumbers").doc(afterData.phoneNumber).delete();
          console.log(
              `Deleted phone number mapping for user ${userIdToDelete}`,
          );
        }

        console.log(
            `Successfully cleaned up all data for ${userIdToDelete}.`,
        );
        return {
          success: true,
          message: `User ${userIdToDelete} fully deleted.`,
        };
      } catch (error) {
        console.error("Error deleting user and their data:", error);
        // Reset the flag to allow for a retry or manual intervention.
        const userDocRef = admin.firestore()
            .collection("users").doc(userIdToDelete);
        if ((await userDocRef.get()).exists) {
          await userDocRef.update({
            deletionRequested: false,
            deletionError: error.message,
          });
        }
        return null;
      }
    });
