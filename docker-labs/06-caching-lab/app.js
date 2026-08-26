const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get("/", (req, res) => {
    res.json({
        message: "Hello from Node.js!",
        hostname: process.env.HOSTNAME || "localhost",
        version: "1.0.0"
    });
});

app.get("/health", (req, res) => {
    res.status(200).json({
        status: "UP"
    });
});

app.get("/ready", (req, res) => {
    res.status(200).json({
        ready: true
    });
});

app.get("/env", (req, res) => {
    res.json(process.env);
});

app.post("/echo", (req, res) => {
    res.json({
        received: req.body
    });
});

app.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
});
