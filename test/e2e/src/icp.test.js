const identityUtils = require("./utils/identity");
const { defaultActor, balanceHolder, recipient } = identityUtils;

const encoder = new TextEncoder();

const testMeta = {
  seller: "ExampleSeller",
  token: "1234",
};
const testInvoice = {
  amount: 10000n,
  token: {
    symbol: "ICP",
  },
  details: [
    {
      description: "Test invoice",
      meta: Array.from(encoder.encode(JSON.stringify(testMeta))),
    },
  ],
};

let createResult;

beforeAll(async () => {
  createResult = await defaultActor.create_invoice(testInvoice);
});

afterAll(async () => {
  let balance = await defaultActor.get_balance({
    token: {
      symbol: "ICP",
    },
  });
  if ("Ok" in balance) {
    let amount = balance.Ok.balance;
    if (amount > 0n) {
      // Transfer full balance back to the balance holder
      defaultActor.transfer({
        amount,
        token: {
          symbol: "ICP",
        },
        destination: {
          text: "cd60093cef12e11d7b8e791448023348103855f682041e93f7d0be451f48118b",
        },
      });
    }
  }
});

describe("ICP Tests", () => {
  /**
   * Account tests
   */
  describe("Account Tests", () => {
    it("should check a caller's icp balance", async () => {
      const balanceResult = await defaultActor.get_balance({
        token: {
          symbol: "ICP",
        },
      });
      expect(balanceResult).toStrictEqual({ Ok: { balance: 0n } });
    });
    it("should fetch the account of the caller", async () => {
      let identifier = await defaultActor.get_caller_identifier({
        token: {
          symbol: "ICP",
        },
      });
      if ("Ok" in identifier) {
        expect(identifier.Ok.accountIdentifier).toStrictEqual({
          // prettier-ignore
          "text": "f834bd307422e47225d915888092810b3eae9daea5e54b67dfc99799698f8eea",
        });
      } else {
        throw new Error("identifier.Err.message");
      }
    });
  });
  /**
   * Invoice Tests
   */
  describe("Invoice Tests", () => {
    it("should create an invoice", async () => {
      if ("Ok" in createResult) {
        // Test invoice exists
        expect(createResult.Ok.invoice).toBeTruthy();

        // Test decoding invoice details
        let metaBlob = Uint8Array.from(createResult.Ok.invoice.details[0].meta);
        let decodedMeta = JSON.parse(String.fromCharCode(...metaBlob));
        expect(decodedMeta).toStrictEqual(testMeta);
      } else {
        throw new Error(createResult.Err.message);
      }
    });
    it("should allow for querying an invoice by ID", async () => {
      const invoice = await defaultActor.get_invoice({
        id: createResult.Ok.invoice.id,
      });
      if ("Ok" in invoice) {
        expect(invoice.Ok.invoice).toStrictEqual(createResult.Ok.invoice);
      } else {
        throw new Error(invoice.Err.message);
      }
    });
    it.skip("should not mark a payment verified if the balance has not been paid", async () => {});
    it.skip("should a payment verified if the balance has been paid", async () => {});
    it.skip("should return AlreadyVerified if an invoice has already been verified", async () => {});
    it.skip("should allow a seller to refund a paid invoice", async () => {});
  });
  /**
   * Transfer Tests
   */
  describe("Transfer Tests", () => {
    it("should increase a caller's icp balance after transferring to that account", async () => {
      let destination = await defaultActor.get_caller_identifier({
        token: { symbol: "ICP" },
      }); //?
      let transferResult = await balanceHolder.transfer({
        amount: 1000000n,
        token: {
          symbol: "ICP",
        },
        destination: destination.Ok.accountIdentifier,
      });
      console.log(transferResult);
      if ("Ok" in transferResult) {
        let newBalance = await defaultActor.get_balance({
          token: {
            symbol: "ICP",
          },
        });
        console.log(newBalance);
        // prettier-ignore
        expect(newBalance).toStrictEqual({ "Ok": { balance: 990000n } });
      }
    });
    it.skip("should allow a caller to transfer out of their account to another valid account", async () => {});
    it.skip("should not allow a caller to transfer to an invalid account", async () => {});
    it.skip("should not allow a caller to transfer more than their balance", async () => {});
  });
});
