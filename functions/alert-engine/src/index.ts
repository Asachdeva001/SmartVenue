import { Firestore } from "@google-cloud/firestore";
import { PubSub } from "@google-cloud/pubsub";
import { cloudEvent } from "@google-cloud/functions-framework";

type GateEvent = {
  eventId: string;
  eventType: string;
  venueId: string;
  timestamp: string;
  payload: Record<string, unknown>;
};

const firestore = new Firestore();
const pubsub = new PubSub();
const alertsTopic = process.env.ALERTS_TOPIC || "smartvenue.alerts";
const waitThresholdSec = Number(process.env.GATE_WAIT_THRESHOLD_SEC || 600);

cloudEvent("runAlertEngine", async (event: { data?: { message?: { data?: string } } }) => {
  const messageData = (event.data as { message?: { data?: string } })?.message?.data;
  if (!messageData) {
    return;
  }

  const decoded = Buffer.from(messageData, "base64").toString("utf8");
  const incoming = JSON.parse(decoded) as GateEvent;
  if (incoming.eventType !== "gate.scan") {
    return;
  }

  const wait = Number(incoming.payload.estimatedWaitSec || 0);
  if (wait < waitThresholdSec) {
    return;
  }

  const alert = {
    alertId: `${incoming.eventId}-gate-wait`,
    venueId: incoming.venueId,
    type: "gate.wait.threshold",
    severity: "high",
    triggeredAt: incoming.timestamp,
    details: {
      gateId: String(incoming.payload.gateId || "unknown"),
      estimatedWaitSec: wait,
      thresholdSec: waitThresholdSec
    }
  };

  await firestore
    .collection("venues")
    .doc(incoming.venueId)
    .collection("alerts")
    .doc(alert.alertId)
    .set(alert, { merge: true });

  await pubsub.topic(alertsTopic).publishMessage({
    data: Buffer.from(JSON.stringify(alert)),
    attributes: {
      venueId: incoming.venueId,
      severity: alert.severity
    }
  });

  console.log(`Alert emitted: ${alert.alertId}`);
});
