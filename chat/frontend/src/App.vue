<template>
    <div id="app">
        <h1>Live Chat</h1>
        <div class="chat-container">
            <div class="messages" ref="messagesContainer">
                <div v-for="(msg, index) in messages" :key="index" class="message">
                    <strong>{{ msg.username }}</strong> ({{ formatTime(msg.timestamp) }}): {{ msg.message }}
                </div>
            </div>
            <div class="input-area">
                <input v-model="username" placeholder="Your Name" class="input-field" />
                <input v-model="newMessage" placeholder="Type a message..." class="input-field"
                    @keyup.enter="sendMessage" />
                <button @click="sendMessage" class="send-button">Send</button>
            </div>
        </div>
    </div>
</template>

<script>
import moment from 'moment';

export default {
    name: 'App',
    data() {
        return {
            username: '',
            newMessage: '',
            messages: [],
            socket: null
        };
    },
    mounted() {
        this.connectWebSocket();
    },
    methods: {
        connectWebSocket() {
            // Connect to chat backend pe portul 88 (NodePort 30088)
            const host = window.location.hostname;
            const port = 30088; // NodePort pentru chat backend

            // Create WebSocket connection
            this.socket = new WebSocket(`ws://${host}:${port}`);

            this.socket.onopen = () => {
                console.log('Connected to WebSocket server');
            };

            this.socket.onmessage = (event) => {
                const data = JSON.parse(event.data);

                if (data.type === 'history') {
                    this.messages = data.data;
                } else if (data.type === 'message') {
                    this.messages.push(data.data);
                    this.$nextTick(() => {
                        this.scrollToBottom();
                    });
                }
            };

            this.socket.onclose = () => {
                console.log('Disconnected from WebSocket server');
                // Try to reconnect after a delay
                setTimeout(() => {
                    this.connectWebSocket();
                }, 5000);
            };

            this.socket.onerror = (error) => {
                console.error('WebSocket error:', error);
            };
        },
        sendMessage() {
            if (!this.newMessage.trim() || !this.username.trim()) {
                return;
            }

            const message = {
                username: this.username,
                text: this.newMessage
            };

            this.socket.send(JSON.stringify(message));
            this.newMessage = '';
        },
        formatTime(timestamp) {
            return moment(timestamp).format('HH:mm:ss');
        },
        scrollToBottom() {
            if (this.$refs.messagesContainer) {
                this.$refs.messagesContainer.scrollTop = this.$refs.messagesContainer.scrollHeight;
            }
        }
    }
};
</script>

<style>
#app {
    font-family: Arial, sans-serif;
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
}

.chat-container {
    border: 1px solid #ccc;
    border-radius: 5px;
    overflow: hidden;
}

.messages {
    height: 400px;
    overflow-y: auto;
    padding: 10px;
    background-color: #f9f9f9;
}

.message {
    margin-bottom: 10px;
}

.input-area {
    display: flex;
    padding: 10px;
    background-color: #eee;
}

.input-field {
    flex: 1;
    padding: 8px;
    margin-right: 10px;
    border: 1px solid #ccc;
    border-radius: 3px;
}

.send-button {
    padding: 8px 15px;
    background-color: #4CAF50;
    color: white;
    border: none;
    border-radius: 3px;
    cursor: pointer;
}

.send-button:hover {
    background-color: #45a049;
}
</style>