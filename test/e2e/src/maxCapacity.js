import { Principal } from "@dfinity/principal";
import { Ed25519KeyIdentity, Secp256k1KeyIdentity } from "@dfinity/identity";
import { createActor } from "./declarations/invoice";
const fetch = require("isomorphic-fetch");
const identityUtils = require("./utils/identity");
const cliProgress = require("cli-progress");
const { defaultActor, defaultIdentity, balanceHolder } = identityUtils;

const bar1 = new cliProgress.SingleBar({}, cliProgress.Presets.shades_classic);
const encoder = new TextEncoder();

const { exec } = require("child_process");
(async () => {
  // const canisterId = await new Promise((resolve, reject) => {
  //   exec("dfx canister id invoice", (err, result) => {
  //     if (err) {
  //       reject(err);
  //     }
  //     resolve(result.trim());
  //   });
  // });
  const canisterId = "r7inp-6aaaa-aaaaa-aaabq-cai";
  const randomActor = () => {
    const identity = Secp256k1KeyIdentity.generate();
    return createActor(canisterId, {
      agentOptions: {
        identity,
        fetch: fetch,
        host: "https://ic0.app",
      },
    });
  };

  const excessiveCanGet = {
    amount: 1_000_000n,
    token: {
      symbol: "ICP",
    },
    details: [
      {
        description: new Array(256).fill("a").join(""),
        meta: new Array(320).fill(0),
      },
    ],
    permissions: [
      {
        canGet: new Array(256).fill(Principal.fromText("aaaaa-aa")),
        canVerify: [],
      },
    ],
  };
  const maxCapacity = {
    amount: 1_000_000n,
    token: {
      symbol: "ICP",
    },
    details: [
      {
        description: new Array(256).fill("a").join(""),
        meta: new Array(320).fill(0),
      },
    ],
    permissions: [
      {
        canGet: new Array(256).fill(Principal.fromText("aaaaa-aa")),
        canVerify: new Array(256).fill(Principal.fromText("aaaaa-aa")),
      },
    ],
  };

  (async () => {
    bar1.start(8_000, 0);

    let count = 0;
    for (let index = 0; index < 8_000; index++) {
      let result = await defaultActor.create_invoice(maxCapacity);
      count += 1;
      bar1.update(count);
      if (!result.ok) {
        break;
      }
      // try {
      //   let promises = [];
      //   for (let i = 0; i < 10; i++) {
      //     promises.push(randomActor().create_invoice(maxCapacity));
      //   }
      //   await Promise.all(promises);
      //   count += 10;
      //   bar1.update(count);
      // } catch (error) {
      //   console.error(error);
      // }
    }

    const lastSuccessful = await defaultActor.create_invoice(maxCapacity);
    console.log(lastSuccessful);

    // const shouldFail = await defaultActor.create_invoice(maxCapacity);
    // console.log(shouldFail);
  })();
})();
