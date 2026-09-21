'use strict';

const Turn = require('node-turn');

const isProduction = process.env.NODE_ENV === 'production';
const developmentExternalIp = '192.168.1.39';

function required(name) {
    const value = process.env[name];
    if (!value || !value.trim()) {
        throw new Error(`${name} must be configured when NODE_ENV=production.`);
    }
    return value.trim();
}

function port(name, fallback) {
    const value = process.env[name] || String(fallback);
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < 1 || parsed > 65535) {
        throw new Error(`${name} must be an integer between 1 and 65535.`);
    }
    return parsed;
}

function portRange() {
    const min = port('TURN_RELAY_MIN_PORT', 49152);
    const max = port('TURN_RELAY_MAX_PORT', 65535);
    if (min > max) {
        throw new Error('TURN_RELAY_MIN_PORT must not exceed TURN_RELAY_MAX_PORT.');
    }
    return { min, max };
}

const externalIp = isProduction
    ? required('TURN_EXTERNAL_IP')
    : (process.env.TURN_EXTERNAL_IP || developmentExternalIp);
const username = isProduction ? required('TURN_USERNAME') : (process.env.TURN_USERNAME || 'turnuser');
const password = isProduction ? required('TURN_PASSWORD') : (process.env.TURN_PASSWORD || 'dev-turn-password');
const relayPorts = portRange();

const server = new Turn({
    listeningPort: port('TURN_LISTENING_PORT', 3478),
    // node-turn expects `externalIps`; it rewrites relay allocations behind NAT.
    externalIps: externalIp,
    minPort: relayPorts.min,
    maxPort: relayPorts.max,
    authMech: 'long-term',
    credentials: {
        [username]: password
    }
});

server.start();
console.log(`TURN server listening on UDP ${port('TURN_LISTENING_PORT', 3478)}; external IP: ${externalIp}`);
