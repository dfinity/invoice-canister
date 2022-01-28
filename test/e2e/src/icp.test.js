const identityUtils = require("./utils/identity");
const { defaultActor, balanceHolder, recipient } = identityUtils;

const encoder = new TextEncoder();

const FEE = 10000n;

const testMeta = {
  seller: "ExampleSeller",
  token: "1234",
};
const testInvoice = {
  amount: 1000000n,
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

const resetBalance = async () => {
  let balance = await defaultActor.get_balance({
    token: {
      symbol: "ICP",
    },
  });
  if ("Ok" in balance) {
    let amount = balance.Ok.balance;
    if (amount > 0n) {
      // Transfer full balance back to the balance holder
      let result = await defaultActor.transfer({
        amount,
        token: {
          symbol: "ICP",
        },
        destination: {
          text: "cd60093cef12e11d7b8e791448023348103855f682041e93f7d0be451f48118b",
        },
      });
      return result;
    }
  }
};
afterEach(async () => {
  await resetBalance();
});
afterAll(async () => {
  await resetBalance();
});

jest.setTimeout(60000);

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
    it("should not mark a payment verified if the balance has not been paid", async () => {
      let verifyResult = await defaultActor.verify_invoice({
        id: createResult.Ok.invoice.id,
      });
      expect(verifyResult).toStrictEqual({
        Err: {
          kind: { NotYetPaid: null },
          message: ["Insufficient balance. Current Balance is 0"],
        },
      });
    });
    it("should a payment verified if the balance has been paid", async () => {
      // Transfer balance to the balance holder
      await balanceHolder.transfer({
        amount: createResult.Ok.invoice.amount + FEE,
        token: {
          symbol: "ICP",
        },
        destination: createResult.Ok?.invoice?.destination,
      });

      // Verify the invoice
      let verifyResult = await defaultActor.verify_invoice({
        id: createResult.Ok.invoice.id,
      });
      expect(verifyResult.Ok?.Paid?.invoice?.paid).toBe(true);
    });
  });
  describe("Refund Tests", () => {
    it("should handle a full flow, with a refund", async () => {
      const newInvoice = await defaultActor.create_invoice(testInvoice);
      await balanceHolder.transfer({
        amount: newInvoice.Ok.invoice.amount + FEE,
        token: {
          symbol: "ICP",
        },
        destination: newInvoice.Ok?.invoice?.destination,
      });
      const verification = await defaultActor.verify_invoice({
        id: newInvoice.Ok.invoice.id,
      });
      expect(verification.Ok?.Paid?.invoice?.paid).toBe(true);

      const refund = await defaultActor.refund_invoice({
        id: newInvoice.Ok.invoice.id,
        // refunding the full amount minus the fee
        amount: newInvoice.Ok.invoice.amount - FEE,
        refundAccount: {
          text: "cd60093cef12e11d7b8e791448023348103855f682041e93f7d0be451f48118b".toUpperCase(),
        },
      });
      expect(refund.Ok).toBeTruthy();
    });
    it("should handle refund errors successfully", async () => {
      const newInvoice = await defaultActor.create_invoice(testInvoice);
      await balanceHolder.transfer({
        amount: newInvoice.Ok.invoice.amount + FEE,
        token: {
          symbol: "ICP",
        },
        destination: newInvoice.Ok?.invoice?.destination,
      });
      const verification = await defaultActor.verify_invoice({
        id: newInvoice.Ok.invoice.id,
      });
      expect(verification.Ok?.Paid?.invoice?.paid).toBe(true);

      const refund = await defaultActor.refund_invoice({
        id: newInvoice.Ok.invoice.id,
        // The balance will be {FEE} less than the amount at this point
        amount: newInvoice.Ok.invoice.amount,
        refundAccount: {
          text: "cd60093cef12e11d7b8e791448023348103855f682041e93f7d0be451f48118b",
        },
      });
      expect(refund).toStrictEqual({
        Err: {
          kind: { InsufficientFunds: null },
          message: ["Insufficient funds"],
        },
      });
    });
  });
  describe("already completed Invoice", () => {
    it("should return AlreadyVerified if an invoice has already been verified", async () => {
      let verifyResult = await defaultActor.verify_invoice({
        id: createResult.Ok.invoice.id,
      });
      expect(verifyResult.Ok.AlreadyVerified).toBeTruthy();
    });
  });
  /**
   * Transfer Tests
   */
  describe("Transfer Tests", () => {
    it("should increase a caller's icp balance after transferring to that account", async () => {
      resetBalance(); //?
      let destination = await defaultActor.get_caller_identifier({
        token: { symbol: "ICP" },
      });
      let transferResult = await balanceHolder.transfer({
        amount: 1000000n,
        token: {
          symbol: "ICP",
        },
        destination: destination.Ok.accountIdentifier,
      });
      if ("Ok" in transferResult) {
        let newBalance = await defaultActor.get_balance({
          token: {
            symbol: "ICP",
          },
        });
        expect(newBalance).toStrictEqual({ Ok: { balance: 1000000n - FEE } });
      }
    });
    it("should not allow a caller to transfer to an invalid account", async () => {
      let transferResult = await balanceHolder.transfer({
        amount: 1000000n,
        token: {
          symbol: "ICP",
        },
        destination: {
          text: "abc123",
        },
      });
      expect(transferResult).toStrictEqual({
        Err: {
          kind: { InvalidDestination: null },
          message: ["Invalid destination account identifier for ICP"],
        },
      });
    });
    it("should not allow a caller to transfer more than their balance", async () => {
      let transferResult = await defaultActor.transfer({
        amount: 1000000n,
        token: {
          symbol: "ICP",
        },
        destination: {
          text: "cd60093cef12e11d7b8e791448023348103855f682041e93f7d0be451f48118b",
        },
      });
      expect(transferResult.Err).toBeTruthy();
    });
  });
});
