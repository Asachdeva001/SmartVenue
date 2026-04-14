import express from "express";
import { Firestore } from "@google-cloud/firestore";
import { PubSub } from "@google-cloud/pubsub";
import { z } from "zod";

const app = express();
app.use(express.json({ limit: "1mb" }));

const port = Number(process.env.PORT || 8080);
const projectId = process.env.GCP_PROJECT_ID;
const topicName = process.env.INGEST_TOPIC || "smartvenue.events.raw";

const firestore = new Firestore(projectId ? { projectId } : {});
const pubsub = new PubSub(projectId ? { projectId } : {});

const eventSchema = z.object({
  eventId: z.string().min(3),
  eventType: z.enum(["iot.sensor", "gate.scan", "mobile.signal", "incident.reported"]),
  venueId: z.string().min(1),
  timestamp: z.string(),
  payload: z.record(z.any())
});

app.get("/healthz", (_req, res) => {
  res.status(200).json({ status: "ok", service: "smartvenue-backend" });
});

app.post("/api/events", async (req, res) => {
  const parsed = eventSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: "Invalid event payload", details: parsed.error.flatten() });
  }

  const event = parsed.data;
  const encoded = Buffer.from(JSON.stringify(event));
  await pubsub.topic(topicName).publishMessage({
    data: encoded,
    attributes: {
      eventType: event.eventType,
      venueId: event.venueId
    }
  });

  return res.status(202).json({ accepted: true, eventId: event.eventId });
});

app.get("/api/venues/:venueId/ops-state", async (req, res) => {
  const { venueId } = req.params;
  const gateSnap = await firestore.collection("venues").doc(venueId).collection("gates").get();
  const concessionSnap = await firestore.collection("venues").doc(venueId).collection("concessions").get();
  const incidentSnap = await firestore.collection("venues").doc(venueId).collection("incidents").get();

  return res.status(200).json({
    venueId,
    gates: gateSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    concessions: concessionSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    incidents: incidentSnap.docs.map((d) => ({ id: d.id, ...d.data() }))
  });
});

app.listen(port, () => {
  console.log(`SmartVenue backend listening on :${port}`);
});
