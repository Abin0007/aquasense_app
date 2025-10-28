/* eslint-disable max-len */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const KNear = require("knn");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");

admin.initializeApp();
const db = admin.firestore();

// --- Prediction Function Helpers ---
const ConsumptionCategory = {
  efficient: 0,
  average: 1,
  high: 2,
  veryHigh: 3,
};
const categoryNames = ["efficient", "average", "high", "veryHigh"];

const EFFICIENT_THRESHOLD = 10.0;
const AVERAGE_THRESHOLD = 25.0;
const HIGH_THRESHOLD = 40.0;

/**
 * Converts a numerical consumption value to a category index.
 * @param {number} consumption The monthly consumption value.
 * @return {number} The corresponding category index.
 */
function getCategoryForConsumption(consumption) {
  if (consumption <= EFFICIENT_THRESHOLD) {
    return ConsumptionCategory.efficient;
  } else if (consumption <= AVERAGE_THRESHOLD) {
    return ConsumptionCategory.average;
  } else if (consumption <= HIGH_THRESHOLD) {
    return ConsumptionCategory.high;
  } else {
    return ConsumptionCategory.veryHigh;
  }
}
// --- End Prediction Helpers ---

// ======================================================================
// === PREDICTION CLOUD FUNCTION (HTTPS Callable - v1) ==================
// ======================================================================
/**
 * Predicts the next month's water consumption category for a user using KNN.
 * Requires userId and wardId in the data payload.
 * Must be called by an authenticated user. (NOTE: Auth check temporarily bypassed)
 * @param {object} data The data passed to the function.
 * @param {string} data.userId The ID of the user to predict for.
 * @param {string} data.wardId The Ward ID of the user.
 * @param {functions.https.CallableContext} context The context of the call,
 * including authentication information.
 * @return {Promise<{category: string|null}>} A promise resolving with the
 * predicted category name (e.g., "average") or null if prediction cannot
 * be made due to errors or insufficient data.
 */
exports.predictConsumption = functions.https.onCall(async (data, context) => {
  // --- TEMPORARILY COMMENT OUT AUTH CHECK ---
  /*
  functions.logger.info("Function called. Checking context.auth...");
  if (context.auth) {
    functions.logger.info(`Authentication context present. UID: ${context.auth.uid}`);
  } else {
    functions.logger.warn("Authentication context (context.auth) is NULL or UNDEFINED.");
    throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated (context.auth is missing).",
    );
  }
  */
  // --- END TEMPORARY COMMENT OUT ---

  // Ensure data is still passed correctly, even if auth is bypassed for now
  const userId = data.userId;
  const wardId = data.wardId;
  // Add log to indicate bypass
  functions.logger.info(`Auth check bypassed for review demo. Processing for user ${userId} in ward ${wardId}`);

  if (!userId || !wardId) {
    functions.logger.error("Missing userId or wardId in request data:", data);
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Please provide userId and wardId.",
    );
  }

  // 2. Fetch Training Data (Keep existing logic - check logs if this part fails now)
  const allDataRows = [];
  try {
    const usersSnapshot = await db.collection("users")
        .where("wardId", "==", wardId).get();
    functions.logger.info(
        `Found ${usersSnapshot.docs.length} users in ward ${wardId}`,
    );

    for (const userDoc of usersSnapshot.docs) {
      const billingHistorySnapshot = await userDoc.ref
          .collection("billingHistory")
          .orderBy("date", "asc")
          .get();

      if (billingHistorySnapshot.docs.length > 1) {
        const bills = billingHistorySnapshot.docs.map((doc) => doc.data());
        const monthlyConsumptions = [];

        for (let i = 1; i < bills.length; i++) {
          const dateCurrent = bills[i].date.toDate();
          const datePrevious = bills[i - 1].date.toDate();
          const diffDays = (
            dateCurrent.getTime() - datePrevious.getTime()
          ) / (1000 * 3600 * 24);

          if (diffDays > 20 && diffDays < 40) {
            const consumption = Math.max(0, (bills[i].reading || 0) -
                                            (bills[i - 1].reading || 0));
            monthlyConsumptions.push(consumption);
          }
        }

        if (monthlyConsumptions.length > 0) {
          const averageConsumption = monthlyConsumptions
              .reduce((a, b) => a + b, 0) / monthlyConsumptions.length;
          let validIntervalsCount = 0;
          for (let i = 0; i < monthlyConsumptions.length - 1; i++) {
            const billDate = bills[i + 1].date.toDate();
            const targetCategory = getCategoryForConsumption(
                monthlyConsumptions[i+1],
            );
            allDataRows.push([
              Number(averageConsumption),
              Number(billDate.getMonth() + 1),
              Number(targetCategory),
            ]);
            validIntervalsCount++;
          }
          if (validIntervalsCount > 0) {
            functions.logger.debug(
                `Added ${validIntervalsCount} rows for user ${userDoc.id}`,
            );
          } else {
            functions.logger.debug(
                `Skipping user ${userDoc.id}, no sequential intervals.`,
            );
          }
        } else {
          functions.logger.debug(
              `Skipping user ${userDoc.id}, no valid consumption periods.`,
          );
        }
      } else {
        functions.logger.debug(
            `Skipping user ${userDoc.id}, not enough history (<2 bills).`,
        );
      }
    } // End user loop
  } catch (error) {
    functions.logger.error("Error fetching training data:", error);
    throw new functions.https.HttpsError(
        "internal", "Could not fetch training data.",
    );
  }

  const K_VALUE = 3;
  if (allDataRows.length < K_VALUE) {
    functions.logger.warn(
        `Insufficient training data (${allDataRows.length} rows) ` +
        `for ward ${wardId}. Needs at least ${K_VALUE}. Cannot predict.`,
    );
    return {category: null};
  }
  functions.logger.info(`Generated ${allDataRows.length} training rows.`);

  // 3. Fetch Target User's Average Consumption (Keep existing logic)
  let currentUserAverageConsumption = 0.0;
  try {
    const userBillingSnapshot = await db.collection("users").doc(userId)
        .collection("billingHistory")
        .orderBy("date", "asc")
        .get();

    if (userBillingSnapshot.docs.length > 1) {
      const bills = userBillingSnapshot.docs.map((doc) => doc.data());
      const consumptions = [];
      for (let i = 1; i < bills.length; i++) {
        const dateCurrent = bills[i].date.toDate();
        const datePrevious = bills[i - 1].date.toDate();
        const diffDays = (
          dateCurrent.getTime() - datePrevious.getTime()
        ) / (1000 * 3600 * 24);

        if (diffDays > 20 && diffDays < 40) {
          consumptions.push(
              Math.max(0, (bills[i].reading || 0) - (bills[i - 1].reading || 0)),
          );
        }
      }
      if (consumptions.length > 0) {
        currentUserAverageConsumption = consumptions
            .reduce((a, b) => a + b, 0) / consumptions.length;
        functions.logger.info(
            `User ${userId} avg consumption: ${currentUserAverageConsumption}`,
        );
      } else {
        functions.logger.warn(
            `No valid periods for current user ${userId}. Cannot predict.`,
        );
        return {category: null};
      }
    } else {
      functions.logger.warn(
          `Insufficient history (<2 bills) for user ${userId}. Cannot predict.`,
      );
      return {category: null};
    }
  } catch (error) {
    functions.logger.error(
        `Error fetching current user ${userId} data:`, error,
    );
    throw new functions.https.HttpsError(
        "internal", "Could not fetch current user data.",
    );
  }

  // 4. Prepare KNN and Predict (Keep existing logic)
  try {
    const kValue = Math.min(K_VALUE, allDataRows.length);
    const knn = new KNear(kValue);

    for (const row of allDataRows) {
      knn.learn(row.slice(0, 2), row[2]);
    }
    functions.logger.info(`KNN Training complete with K=${kValue}`);

    const currentMonth = new Date().getMonth(); // 0-11
    const nextMonth = (currentMonth === 11) ? 1 : currentMonth + 2; // Month (1-12)
    const predictionPoint = [
      Number(currentUserAverageConsumption),
      Number(nextMonth),
    ];
    functions.logger.info(`Prediction point: ${predictionPoint}`);

    const predictedCategoryIndex = knn.classify(predictionPoint);
    functions.logger.info(`Prediction result index: ${predictedCategoryIndex}`);

    if (typeof predictedCategoryIndex !== "number" ||
        predictedCategoryIndex < 0 ||
        predictedCategoryIndex >= categoryNames.length ||
        !Number.isInteger(predictedCategoryIndex)) {
      functions.logger.error(
          `Invalid prediction index: ${predictedCategoryIndex}`,
      );
      return {category: null};
    }

    const categoryName = categoryNames[predictedCategoryIndex];
    functions.logger.info(`Predicted Category Name: ${categoryName}`);
    return {category: categoryName};
  } catch (error) {
    functions.logger.error("Error during KNN prediction:", error);
    return {category: null};
  }
}); // END predictConsumption


// ======================================================================
// === DELETION TRIGGER FUNCTION (Firestore Trigger - v2) ==============
// ======================================================================
/**
 * Handles the deletion of a user and their associated data when the
 * 'deletionRequested' flag is set to true on their user document.
 * Triggered on updates to documents in the 'users' collection.
 * @param {functions.Change<functions.firestore.DocumentSnapshot>} change
 * Object containing the data before and after the change.
 * @param {functions.EventContext} context Context metadata for the event.
 * @return {Promise<object|null>} A promise resolving with a success message
 * or null if no action was taken or an error occurred.
 */
exports.handleDeletionRequest = onDocumentUpdated("users/{userId}", async (event) => {
  // Keep existing deletion logic
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  const userIdToDelete = event.params.userId;

  console.log(`Update event triggered for user: ${userIdToDelete}`);

  // Check if deletion flag was just set to true
  if (!event.data.before.exists || !event.data.after.exists ||
      afterData.deletionRequested !== true ||
      beforeData.deletionRequested === true) { // Avoid re-triggering if flag was already true
    console.log(
        `No deletion action needed for user ${userIdToDelete}. ` +
        "Flag not set/changed correctly, or data missing.",
    );
    return null;
  }


  console.log(
      `Deletion requested for user: ${userIdToDelete}. Starting process...`,
  );

  try {
    // 1. Delete auth user
    await admin.auth().deleteUser(userIdToDelete);
    console.log(`Successfully deleted auth user: ${userIdToDelete}`);

    // 2. Delete Firestore document
    // NOTE: The trigger runs *after* the update that set deletionRequested=true.
    // Deleting the document that triggered the function is standard practice here.
    await event.data.after.ref.delete();
    console.log(`Successfully deleted user document: ${userIdToDelete}`);

    // Batch deletion helper
    const deleteQueryBatch = async (query, batchSize) => {
      const snapshot = await query.limit(batchSize).get();
      if (snapshot.size === 0) return 0;

      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      return snapshot.size;
    };

    // 3. Delete complaints
    const complaintsQuery = db.collection("complaints")
        .where("userId", "==", userIdToDelete);
    let numComplaintsDeleted = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const deletedCount = await deleteQueryBatch(complaintsQuery, 100);
      numComplaintsDeleted += deletedCount;
      if (deletedCount < 100) break;
    }
    console.log(
        `Deleted ${numComplaintsDeleted} complaints for user ${userIdToDelete}`,
    );

    // 4. Delete connection requests
    const requestsQuery = db.collection("connection_requests")
        .where("userId", "==", userIdToDelete);
    let numRequestsDeleted = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const deletedCount = await deleteQueryBatch(requestsQuery, 100);
      numRequestsDeleted += deletedCount;
      if (deletedCount < 100) break;
    }
    console.log(
        `Deleted ${numRequestsDeleted} connection requests for user ` +
        userIdToDelete,
    );

    // 5. Delete billing history
    const billingHistoryRef = db.collection("users").doc(userIdToDelete)
        .collection("billingHistory");
    let numBillingDeleted = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const deletedCount = await deleteQueryBatch(billingHistoryRef, 100);
      numBillingDeleted += deletedCount;
      if (deletedCount < 100) break;
    }
    console.log(
        `Deleted ${numBillingDeleted} billing records for user ${userIdToDelete}`,
    );

    // 6. Delete phone number mapping
    if (afterData.phoneNumber) {
      await db.collection("phoneNumbers").doc(afterData.phoneNumber).delete()
          .catch((err) => {
            console.warn(
                `Could not delete phone number mapping for user ` +
                `${userIdToDelete}: ${err.message}`,
            );
          });
      console.log(
          `Attempted phone mapping deletion for ${userIdToDelete}`,
      );
    } else {
      console.log(
          `No phone number found for user ${userIdToDelete}, skipping mapping deletion.`,
      );
    }

    console.log(
        `Successfully cleaned up data for ${userIdToDelete}.`,
    );
    return {
      success: true,
      message: `User ${userIdToDelete} fully deleted.`,
    };
  } catch (error) {
    console.error(`Error deleting user ${userIdToDelete}:`, error);

    // Attempt to reset the flag only if the user document still exists
    // (it might have been deleted just before the error occurred in Auth deletion)
    try {
      const userDocRef = db.collection("users").doc(userIdToDelete); // Use direct ref
      const userDocSnapshot = await userDocRef.get();
      if (userDocSnapshot.exists) { // Check if it *still* exists after error
        let errorMessage = "Unknown error during deletion";
        if (error instanceof Error && error.message) {
          errorMessage = error.message;
        } else if (error) {
          errorMessage = String(error);
        }
        await userDocRef.update({
          deletionRequested: false, // Reset flag
          deletionError: `Error: ${errorMessage}`, // Store error
        });
        console.log(
            `Reset deletionRequested flag for ${userIdToDelete} due to error.`,
        );
      } else {
        console.log(
            `User doc ${userIdToDelete} no longer exists after error. Cannot reset flag.`,
        );
      }
    } catch (updateError) {
      console.error(
          `Failed to reset deletion flag for ${userIdToDelete}:`,
          updateError,
      );
    }
    // Return null to indicate the trigger finished, even with an error during cleanup
    return null;
  }
}); // END handleDeletionRequest
