import { Firestore } from "@google-cloud/firestore";
import { cloudEvent } from "@google-cloud/functions-framework";

type SmartVenueEvent = {
  eventId: string;
  eventType: "iot.sensor" | "gate.scan" | "mobile.signal" | "incident.reported";
  venueId: string;
  timestamp: string;
  payload: Record<string, unknown>;
};

const firestore = new Firestore();

cloudEvent("processSmartVenueEvent", async (event: { data?: { message?: { data?: string } } }) => {
  const messageData = (event.data as { message?: { data?: string } })?.message?.data;
  if (!messageData) {
    console.warn("No message data found");
    return;
  }

  const decoded = Buffer.from(messageData, "base64").toString("utf8");
  const payload = JSON.parse(decoded) as SmartVenueEvent;

  const venueRef = firestore.collection("venues").doc(payload.venueId);

  if (payload.eventType === "gate.scan") {
    const gateId = String(payload.payload.gateId || "unknown");
    await venueRef.collection("gates").doc(gateId).set(
      {
        lastEventId: payload.eventId,
        lastUpdatedAt: payload.timestamp,
        throughput: Number(payload.payload.throughput || 0),
        estimatedWaitSec: Number(payload.payload.estimatedWaitSec || 0)
      },
      { merge: true }
    );
  }

  if (payload.eventType === "iot.sensor") {
    const zoneId = String(payload.payload.zoneId || "unknown");
    await venueRef.collection("zones").doc(zoneId).set(
      {
        densityScore: Number(payload.payload.densityScore || 0),
        lastUpdatedAt: payload.timestamp
      },
      { merge: true }
    );
  }

  if (payload.eventType === "incident.reported") {
    const incidentId = String(payload.payload.incidentId || payload.eventId);
    await venueRef.collection("incidents").doc(incidentId).set(
      {
        severity: String(payload.payload.severity || "medium"),
        status: "open",
        reportedAt: payload.timestamp,
        source: String(payload.payload.source || "unknown")
      },
      { merge: true }
    );
  }

  console.log(`Processed event ${payload.eventId} (${payload.eventType}) for venue ${payload.venueId}`);
});
