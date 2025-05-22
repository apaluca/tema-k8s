const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const mongoose = require('mongoose');
const cors = require('cors');
const moment = require('moment');

// Connect to MongoDB
mongoose.connect('mongodb://chat-db:27017/chatdb', {
    useNewUrlParser: true,
    useUnifiedTopology: true
}).catch(err => console.error('MongoDB connection error:', err));

// Define Message schema
const messageSchema = new mongoose.Schema({
    username: String,
    message: String,
    timestamp: { type: Date, default: Date.now }
});

const Message = mongoose.model('Message', messageSchema);

// Create Express app
const app = express();
app.use(cors());
app.use(express.json());

// Define API routes
app.get('/messages', async (req, res) => {
    try {
        const messages = await Message.find().sort({ timestamp: 1 });
        res.json(messages);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Create HTTP server
const server = http.createServer(app);

// Create WebSocket server
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
    console.log('Client connected');

    // Send historical messages when a client connects
    Message.find().sort({ timestamp: 1 }).then(messages => {
        ws.send(JSON.stringify({ type: 'history', data: messages }));
    });

    ws.on('message', async (message) => {
        try {
            const data = JSON.parse(message.toString());
            const { username, text } = data;

            // Create new message
            const newMessage = new Message({
                username,
                message: text,
                timestamp: new Date()
            });

            // Save to database
            await newMessage.save();

            // Broadcast to all clients
            const broadcastMessage = {
                type: 'message',
                data: {
                    username,
                    message: text,
                    timestamp: newMessage.timestamp
                }
            };

            wss.clients.forEach(client => {
                if (client.readyState === WebSocket.OPEN) {
                    client.send(JSON.stringify(broadcastMessage));
                }
            });
        } catch (err) {
            console.error('Error processing message:', err);
        }
    });

    ws.on('close', () => {
        console.log('Client disconnected');
    });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});