const express = require('express');
const fs = require('fs');
const app = express();
const PORT = process.env.PORT || 8080;

app.get('/', (req, res) => {
    try {
        fs.writeFileSync('/tmp/app.log', `Request at ${new Date().toISOString()}\n`, { flag: 'a' });
        res.json({ message: 'App running on read-only root filesystem', status: 'OK' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
});
