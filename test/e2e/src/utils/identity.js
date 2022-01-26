const Identity = require("@dfinity/identity");
const sha256 = require("sha256");
const fs = require("fs");
const Path = require("path");
const localCanisterIds = require("../../../../.dfx/local/canister_ids.json");
const canisterId = localCanisterIds.invoice.local;
const fetch = require("isomorphic-fetch");

const { Secp256k1KeyIdentity } = Identity;
const declarations = require("../declarations/invoice");

const parseIdentity = (keyPath) => {
  const rawKey = fs
    .readFileSync(Path.join(__dirname, keyPath))
    .toString()
    .replace("-----BEGIN EC PRIVATE KEY-----", "")
    .replace("-----END EC PRIVATE KEY-----", "")
    .trim();

  const rawBuffer = Uint8Array.from(rawKey).buffer;

  const privKey = Uint8Array.from(sha256(rawBuffer, { asBytes: true }));

  // Initialize an identity from the secret key
  return Secp256k1KeyIdentity.fromSecretKey(Uint8Array.from(privKey).buffer);
};

const { createActor } = declarations;

const defaultActor = createActor(canisterId, {
  agentOptions: {
    identity: parseIdentity("test-ec-secp256k1-priv-key.pem"),
    fetch,
    host: "http://localhost:8000",
  },
});

// Account that will receive a large balance of ICP for testing from install.sh
const balanceHolder = createActor(canisterId, {
  agentOptions: {
    identity: parseIdentity("test-ec-secp256k1-priv-key-moneybags.pem"),
    fetch,
    host: "http://localhost:8000",
  },
});

// Account that will receive a large balance of ICP for testing from install.sh
const recipient = createActor(canisterId, {
  agentOptions: {
    identity: parseIdentity("test-ec-secp256k1-priv-key-broke.pem"),
    fetch,
    host: "http://localhost:8000",
  },
});

module.exports = {
  defaultActor,
  balanceHolder,
  recipient,
};
