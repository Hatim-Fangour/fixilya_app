'use strict';
/**
 * Agora AccessToken V2 (version "007") generator.
 *
 * Implements the same algorithm as Agora's official Node.js SDK
 * (AgoraDynamicKey/nodejs/src/AccessToken2.js) without requiring
 * the external `agora-access-token` package.
 *
 * Ref: https://github.com/AgoraIO/Tools/tree/master/DynamicKey/AgoraDynamicKey
 */

const crypto = require('crypto');

// ── Constants ────────────────────────────────────────────────────────────────

const VERSION = '007';

const SERVICE_TYPE_RTC = 1;

// RTC channel privileges
const PRIVILEGE_JOIN_CHANNEL = 1;
const PRIVILEGE_PUBLISH_AUDIO = 2;
const PRIVILEGE_PUBLISH_VIDEO = 3;
const PRIVILEGE_PUBLISH_DATA = 4;

// Role codes (mirrors Agora SDK)
const ROLE_PUBLISHER = 1;
const ROLE_SUBSCRIBER = 2;

// ── Low-level byte buffer (little-endian, matching Agora's spec) ─────────────

class BytePacker {
  constructor() {
    this.chunks = [];
  }

  uint16(v) {
    const b = Buffer.alloc(2);
    b.writeUInt16LE(v >>> 0);
    this.chunks.push(b);
    return this;
  }

  uint32(v) {
    const b = Buffer.alloc(4);
    b.writeUInt32LE(v >>> 0);
    this.chunks.push(b);
    return this;
  }

  /** bytes: length-prefixed (uint16 prefix) */
  bytes(buf) {
    this.uint16(buf.length);
    this.chunks.push(buf);
    return this;
  }

  string(s) {
    return this.bytes(Buffer.from(s, 'utf8'));
  }

  /** privileges: map<uint16 key, uint32 value>, prefixed with uint16 count */
  privilegeMap(map) {
    const entries = Object.entries(map);
    this.uint16(entries.length);
    for (const [k, v] of entries) {
      this.uint16(Number(k));
      this.uint32(Number(v));
    }
    return this;
  }

  pack() {
    return Buffer.concat(this.chunks);
  }
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Build an Agora RTC AccessToken V2.
 *
 * @param {string} appId          Agora App ID (hex string, 32 chars)
 * @param {string} appCertificate Agora App Certificate (hex string, 32 chars)
 * @param {string} channelName    Target channel name
 * @param {string|number} uid     User ID (0 = wildcard / unspecified)
 * @param {number} role           ROLE_PUBLISHER (1) or ROLE_SUBSCRIBER (2)
 * @param {number} tokenExpire    Seconds until the token itself expires
 * @param {number} [privilegeExpire=tokenExpire] Seconds until join/publish privileges expire
 * @returns {string} Agora token string starting with "007…"
 */
function buildRtcToken(appId, appCertificate, channelName, uid, role, tokenExpire, privilegeExpire) {
  if (!appId || !appCertificate) {
    throw new Error('Agora App ID and App Certificate are required');
  }

  const salt = Math.floor(Math.random() * 0xFFFFFFFF);
  const issueTs = Math.floor(Date.now() / 1000);
  const expireTs = issueTs + tokenExpire;
  const privExpire = privilegeExpire !== undefined ? issueTs + privilegeExpire : expireTs;

  const uidStr = (uid === 0 || uid === '0' || uid === '') ? '' : String(uid);

  // Privileges granted to this token
  const privileges = { [PRIVILEGE_JOIN_CHANNEL]: privExpire };
  if (role === ROLE_PUBLISHER) {
    privileges[PRIVILEGE_PUBLISH_AUDIO] = privExpire;
    privileges[PRIVILEGE_PUBLISH_VIDEO] = privExpire;
    privileges[PRIVILEGE_PUBLISH_DATA] = privExpire;
  }

  // Serialise the RTC service payload
  const servicePayload = new BytePacker()
    .string(channelName)
    .string(uidStr)
    .privilegeMap(privileges)
    .pack();

  // Serialise the services list: [(type, payload)]
  const services = new BytePacker()
    .uint16(1)                         // service count
    .uint16(SERVICE_TYPE_RTC)          // service type
    .bytes(servicePayload)             // service body
    .pack();

  // Serialise the full token message
  const message = new BytePacker()
    .string(appId)
    .uint32(issueTs)
    .uint32(expireTs)
    .uint32(salt)
    .bytes(services)
    .pack();

  // HMAC-SHA256 signature
  const signature = crypto
    .createHmac('sha256', Buffer.from(appCertificate, 'utf8'))
    .update(message)
    .digest();

  // Final token: VERSION + base64(message ‖ signature)
  const token = Buffer.concat([message, signature]).toString('base64');
  return VERSION + token;
}

module.exports = { buildRtcToken, ROLE_PUBLISHER, ROLE_SUBSCRIBER };
