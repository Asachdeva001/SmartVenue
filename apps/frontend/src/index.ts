import express from "express";

const app = express();
const port = Number(process.env.PORT || 8081);
const backendUrl = process.env.BACKEND_URL || "http://localhost:8080";

app.get("/healthz", (_req, res) => {
  res.status(200).json({ status: "ok", service: "smartvenue-frontend" });
});

app.get("/", (_req, res) => {
  res.type("html").send(`<!doctype html>
<html>
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width,initial-scale=1"/>
    <title>SmartVenue Ops</title>
  </head>
  <body style="font-family:Arial,sans-serif;padding:20px">
    <h1>SmartVenue Operations</h1>
    <p>Backend endpoint: ${backendUrl}</p>
    <p>This is a starter Cloud Run frontend. Connect dashboards through Looker Studio and Firestore-backed APIs.</p>
  </body>
</html>`);
});

app.listen(port, () => {
  console.log(`SmartVenue frontend listening on :${port}`);
});
