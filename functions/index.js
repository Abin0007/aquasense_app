/* eslint-disable max-len */ // Keep disabling max-len for safety, but tried to fix below
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const KNear = require("knn"); // Use 'knn' package
// Import the v2 trigger function for Firestore
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");

// Initialize Firebase Admin SDK (only once)
admin.initializeApp();
const db = admin.firestore();

// --- Prediction Function Helpers ---
const ConsumptionCategory = {
  efficient: 0,
  average: 1,
  high: 2,
  veryHigh: 3,
};
// Helper to get enum name from index
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
 * Predicts the next month's water consumption category for a user.
 * @param {object} data The data passed to the function.
 * @param {string} data.userId The ID of the user to predict for.
 * @param {string} data.wardId The Ward ID of the user.
 * @param {functions.https.CallableContext} context The context of the call.
 * @return {Promise<{category: string|null}>} A promise resolving with the
 * predicted category name or null.
 */
exports.predictConsumption = functions.https.onCall(async (data, context) => {
  // 1. Authenticate and get input data
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }
  const userId = data.userId;
  const wardId = data.wardId;

  if (!userId || !wardId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Please provide userId and wardId.",
    );
  }

  functions.logger.info(
      `Starting prediction for user ${userId} in ward ${wardId}`,
  );

  // 2. Fetch Training Data
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

        // Calculate monthly consumptions first
        for (let i = 1; i < bills.length; i++) {
          const dateCurrent = bills[i].date.toDate();
          const datePrevious = bills[i - 1].date.toDate();
          // Check if interval is roughly a month (e.g., 20-40 days)
          const diffDays = (
            dateCurrent.getTime() - datePrevious.getTime()
          ) / (1000 * 3600 * 24);

          // Only consider intervals roughly a month long
          if (diffDays > 20 && diffDays < 40) {
            const consumption = Math.max(0, (bills[i].reading || 0) -
                                            (bills[i - 1].reading || 0));
            monthlyConsumptions.push(consumption);
          }
        }

        // Create training rows using average and category of next known month
        if (monthlyConsumptions.length > 0) {
          const averageConsumption = monthlyConsumptions
              .reduce((a, b) => a + b, 0) / monthlyConsumptions.length;
          let validIntervalsCount = 0;
          // Loop up to second to last consumption to predict the last one
          for (let i = 0; i < monthlyConsumptions.length - 1; i++) {
            // Assumes monthlyConsumptions[i] corresponds to consumption
            // *ending* at bills[i+1].date
            const billDate = bills[i + 1].date.toDate(); // Date recorded
            // Predict next month's category
            const targetCategory = getCategoryForConsumption(
                monthlyConsumptions[i+1],
            );

            allDataRows.push([
              Number(averageConsumption),
              Number(billDate.getMonth() + 1), // Month (1-12) recorded
              Number(targetCategory), // Category Index of *next* period
            ]);
            validIntervalsCount++;
          }
          if (validIntervalsCount > 0) {
            functions.logger.debug(
                `Added ${validIntervalsCount} rows for user ${userDoc.id}`,
            );
          } else {
            // Log if no sequential intervals were found for training row generation
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

  // Need enough data for KNN (adjust K if needed)
  const K_VALUE = 3; // Use a smaller K
  if (allDataRows.length < K_VALUE) {
    // Log insufficient data warning
    functions.logger.warn(
        `Insufficient training data (${allDataRows.length} rows) ` +
        `for ward ${wardId}. Needs at least ${K_VALUE}. Cannot predict.`,
    );
    return {category: null}; // Return null if not enough data
  }
  functions.logger.info(`Generated ${allDataRows.length} training rows.`);

  // 3. Fetch Target User's Average Consumption
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

        if (diffDays > 20 && diffDays < 40) { // Check interval
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
        // Log if no valid periods found for the target user
        functions.logger.warn(
            `No valid periods for current user ${userId}. Cannot predict.`,
        );
        return {category: null};
      }
    } else {
      // Log if target user has insufficient history
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

  // 4. Prepare KNN and Predict
  try {
    // Ensure K is not larger than the number of data points
    const kValue = Math.min(K_VALUE, allDataRows.length);
    const knn = new KNear(kValue);

    // Train the model: features are [avgConsumption, month]
    // Label is categoryIndex
    for (const row of allDataRows) {
      knn.learn(row.slice(0, 2), row[2]);
    }
    functions.logger.info(`KNN Training complete with K=${kValue}`);

    // Create prediction point: use target user's average and the *next* month
    const currentMonth = new Date().getMonth(); // 0-11
    // Handle year wrap-around for December -> January
    const nextMonth = (currentMonth === 11) ? 1 : currentMonth + 2; // Month (1-12)
    const predictionPoint = [
      Number(currentUserAverageConsumption),
      Number(nextMonth),
    ];
    functions.logger.info(`Prediction point: ${predictionPoint}`);

    // Make prediction
    const predictedCategoryIndex = knn.classify(predictionPoint);
    functions.logger.info(`Prediction result index: ${predictedCategoryIndex}`);

    // Check validity
    if (typeof predictedCategoryIndex !== "number" ||
        predictedCategoryIndex < 0 ||
        predictedCategoryIndex >= categoryNames.length ||
        !Number.isInteger(predictedCategoryIndex)) {
      // Log invalid prediction index
      functions.logger.error(
          `Invalid prediction index: ${predictedCategoryIndex}`,
      );
      return {category: null};
    }

    // Return the category name
    const categoryName = categoryNames[predictedCategoryIndex];
    functions.logger.info(`Predicted Category Name: ${categoryName}`);
    return {category: categoryName};
  } catch (error) {
    functions.logger.error("Error during KNN prediction:", error);
    // Return null instead of throwing an error back to the client
    return {category: null};
  }
}); // END predictConsumption


// ======================================================================
// === DELETION TRIGGER FUNCTION (Firestore Trigger - v2) ==============
// ======================================================================
/**
 * Listens for updates on user documents and performs a full deletion if a
 * 'deletionRequested' flag is set to true.
 * v2 Firestore Trigger Syntax.
 */
exports.handleDeletionRequest = onDocumentUpdated("users/{userId}", async (event) => {
  // Get data before and after the change
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  const userIdToDelete = event.params.userId;

  // Log the event for debugging
  console.log(`Update event triggered for user: ${userIdToDelete}`);

  // Check existence of data and the specific flag change
  if (!event.data.before.exists || !event.data.after.exists ||
      afterData.deletionRequested !== true ||
      beforeData.deletionRequested === true) {
    // Log reason for no action
    console.log(
        `No action needed for user ${userIdToDelete}. ` +
        "Flag not set, already processed, data missing, or doc deleted.",
    );
    return null;
  }

  console.log(
      `Deletion requested for user: ${userIdToDelete}. Starting process...`,
  );

  try {
    // 1. Delete user from Firebase Authentication
    await admin.auth().deleteUser(userIdToDelete);
    console.log(`Successfully deleted auth user: ${userIdToDelete}`);

    // 2. Delete the user's document from Firestore
    await event.data.after.ref.delete();
    console.log(`Successfully deleted user document: ${userIdToDelete}`);

    // Batch deletion helper function
    const deleteQueryBatch = async (query, batchSize) => {
      const snapshot = await query.limit(batchSize).get();
      if (snapshot.size === 0) return 0; // Nothing left

      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      return snapshot.size; // Return number deleted
    };

    // 3. Delete associated complaints (in batches)
    const complaintsQuery = db.collection("complaints")
        .where("userId", "==", userIdToDelete);
    let numComplaintsDeleted = 0;
    // Keep deleting batches until no more documents match
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const deletedCount = await deleteQueryBatch(complaintsQuery, 100);
      numComplaintsDeleted += deletedCount;
      if (deletedCount < 100) break; // Stop if less than batch size deleted
    }
    console.log(
        `Deleted ${numComplaintsDeleted} complaints for user ${userIdToDelete}`,
    );

    // 4. Delete associated connection requests (in batches)
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

    // 5. Delete billing history subcollection (in batches)
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
            // Log warning if phone mapping deletion fails
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
    try {
      const userDocRef = event.data.after.ref;
      const userDocSnapshot = await userDocRef.get();
      if (userDocSnapshot.exists) {
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
        // Log if doc already gone after error
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
    return null; // Don't re-throw from trigger
  }
}); // END handleDeletionRequest
