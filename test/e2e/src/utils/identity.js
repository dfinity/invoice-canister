const Identity = require("@dfinity/identity");
const sha256 = require("sha256");
const fs = require("fs");
const Path = require("path");
const localCanisterIds = require("../../../../.dfx/local/canister_ids.json");
const canisterId = localCanisterIds.invoice.local;
const fetch = require("isomorphic-fetch");

const { Secp256k1KeyIdentity } = Identity;
const declarations = require("../declarations/invoice");

const rawKey = fs
  .readFileSync(Path.join(__dirname, "test-ec-secp256k1-priv-key.pem"))
  .toString()
  .replace("-----BEGIN EC PRIVATE KEY-----", "")
  .replace("-----END EC PRIVATE KEY-----", "")
  .trim();

const rawBuffer = Uint8Array.from(rawKey).buffer;

const privKey = Uint8Array.from(sha256(rawBuffer, { asBytes: true }));

// Initialize an identity from the secret key
const identity = Secp256k1KeyIdentity.fromSecretKey(
  Uint8Array.from(privKey).buffer
);

const { createActor } = declarations;

const defaultActor = createActor(canisterId, {
  agentOptions: {
    identity,
    fetch,
    host: "http://localhost:8000",
  },
});

module.exports = {
  defaultActor,
};
