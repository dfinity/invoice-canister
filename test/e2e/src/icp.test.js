const identityUtils = require("./utils/identity");
const { defaultActor, defaultIdentity, balanceHolder } = identityUtils;

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
  permissions: [],
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
  if ("ok" in balance) {
    let amount = balance.ok.balance;
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
      expect(balanceResult).toStrictEqual({ ok: { balance: 0n } });
    });
    it("should fetch the account of the different principals", async () => {
      let identifier = await defaultActor.get_account_identifier({
        token: {
          symbol: "ICP",
        },
        principal: defaultIdentity.getPrincipal(),
      });
      if ("ok" in identifier) {
        expect(identifier.ok.accountIdentifier).toStrictEqual({
          // prettier-ignore
          "text": "f834bd307422e47225d915888092810b3eae9daea5e54b67dfc99799698f8eea",
        });
      } else {
        throw new Error(identifier.err.message);
      }
    });
  });
  /**
   * Invoice Tests
   */
  describe("Invoice Tests", () => {
    it("should create an invoice", async () => {
      if ("ok" in createResult) {
        // Test invoice exists
        expect(createResult.ok.invoice).toBeTruthy();

        // Test decoding invoice details
        let metaBlob = Uint8Array.from(createResult.ok.invoice.details[0].meta);
        let decodedMeta = JSON.parse(String.fromCharCode(...metaBlob));
        expect(decodedMeta).toStrictEqual(testMeta);
      } else {
        throw new Error(createResult.err.message);
      }
    });
    it("should allow for querying an invoice by ID", async () => {
      const invoice = await defaultActor.get_invoice({
        id: createResult.ok.invoice.id,
      });
      if ("ok" in invoice) {
        expect(invoice.ok.invoice).toStrictEqual(createResult.ok.invoice);
      } else {
        throw new Error(invoice.err.message);
      }
    });
    it("should reject get_invoice from unauthorized callers", async () => {
      const invoice = await balanceHolder.get_invoice({
        id: createResult.ok.invoice.id,
      });
      expect(invoice.err).toStrictEqual({
        kind: {
          NotAuthorized: null,
        },
        message: ["You do not have permission to view this invoice"],
      });
    });
    it("should allow get_invoice to be called by authorized callers", async () => {
      const invoice = await defaultActor.create_invoice({
        ...testInvoice,
        permissions: [
          {
            canGet: [identityUtils.balanceHolderIdentity.getPrincipal()],
            canVerify: [],
          },
        ],
      });

      const result = await balanceHolder.get_invoice({
        id: invoice.ok.invoice.id,
      });
      expect(result.ok).toBeTruthy();
    });
    it("should not mark a payment verified if the balance has not been paid", async () => {
      let verifyResult = await defaultActor.verify_invoice({
        id: createResult.ok.invoice.id,
      });
      expect(verifyResult).toStrictEqual({
        err: {
          kind: { NotYetPaid: null },
          message: ["Insufficient balance. Current Balance is 0"],
        },
      });
    });
    it("should mark an invoice verified if the balance has been paid", async () => {
      // Transfer balance to the balance holder
      await balanceHolder.transfer({
        amount: createResult.ok.invoice.amount + FEE,
        token: {
          symbol: "ICP",
        },
        destination: createResult.ok?.invoice?.destination,
      });

      // Verify the invoice
      let verifyResult = await defaultActor.verify_invoice({
        id: createResult.ok.invoice.id,
      });
      expect(verifyResult.ok?.Paid?.invoice?.paid).toBe(true);
    });
    it("should not allow a caller to verify an invoice if they are not the creator or on the allowlist", async () => {
      const invoice = await defaultActor.create_invoice(testInvoice);
      const result = await balanceHolder.verify_invoice({
        id: invoice.ok.invoice.id,
      });
      expect(result.err).toStrictEqual({
        kind: {
          NotAuthorized: null,
        },
        message: ["You do not have permission to verify this invoice"],
      });
    });
    it("should not allow a caller to verify an invoice if they are not the creator or on the allowlist", async () => {
      const invoice = await defaultActor.create_invoice(testInvoice);
      const result = await balanceHolder.verify_invoice({
        id: invoice.ok.invoice.id,
      });
      expect(result.err).toStrictEqual({
        kind: {
          NotAuthorized: null,
        },
        message: ["You do not have permission to verify this invoice"],
      });
    });
    it("should allow a non-creator caller to verify an invoice if they are on the allowlist", async () => {
      const invoice = await defaultActor.create_invoice({
        ...testInvoice,
        permissions: [
          {
            canGet: [],
            canVerify: [identityUtils.balanceHolderIdentity.getPrincipal()],
          },
        ],
      });
      const result = await balanceHolder.verify_invoice({
        id: invoice.ok.invoice.id,
      });
      expect(result.err.kind).toStrictEqual({ NotYetPaid: null });
    });
  });
  describe("Refund Tests", () => {
    it("should handle a full flow, with a refund", async () => {
      const newInvoice = await defaultActor.create_invoice(testInvoice);
      await balanceHolder.transfer({
        amount: newInvoice.ok.invoice.amount + FEE,
        token: {
          symbol: "ICP",
        },
        destination: newInvoice.ok?.invoice?.destination,
      });
      const verification = await defaultActor.verify_invoice({
        id: newInvoice.ok.invoice.id,
      });
      expect(verification.ok?.Paid?.invoice?.paid).toBe(true);

      const refund = await defaultActor.refund_invoice({
        id: newInvoice.ok.invoice.id,
        // refunding the full amount minus the fee
        amount: newInvoice.ok.invoice.amount - FEE,
        refundAccount: {
          text: "cd60093cef12e11d7b8e791448023348103855f682041e93f7d0be451f48118b".toUpperCase(),
        },
      });
      expect(refund.ok).toBeTruthy();
    });
    it("should handle refund errors successfully", async () => {
      const newInvoice = await defaultActor.create_invoice(testInvoice);
      await balanceHolder.transfer({
        amount: newInvoice.ok.invoice.amount + FEE,
        token: {
          symbol: "ICP",
        },
        destination: newInvoice.ok?.invoice?.destination,
      });
      const verification = await defaultActor.verify_invoice({
        id: newInvoice.ok.invoice.id,
      });
      expect(verification.ok?.Paid?.invoice?.paid).toBe(true);

      const refund = await defaultActor.refund_invoice({
        id: newInvoice.ok.invoice.id,
        // The balance will be {FEE} less than the amount at this point
        amount: newInvoice.ok.invoice.amount,
        refundAccount: {
          text: "cd60093cef12e11d7b8e791448023348103855f682041e93f7d0be451f48118b",
        },
      });
      expect(refund).toStrictEqual({
        err: {
          kind: { InsufficientFunds: null },
          message: ["Insufficient balance. Current balance is 990000"],
        },
      });
    });
    it("should only allow the invoice creator to issue a refund", async () => {
      const newInvoice = await defaultActor.create_invoice(testInvoice);
      await balanceHolder.transfer({
        amount: newInvoice.ok.invoice.amount + FEE,
        token: {
          symbol: "ICP",
        },
        destination: newInvoice.ok?.invoice?.destination,
      });
      const verification = await defaultActor.verify_invoice({
        id: newInvoice.ok.invoice.id,
      });
      expect(verification.ok?.Paid?.invoice?.paid).toBe(true);

      const refund = await balanceHolder.refund_invoice({
        id: newInvoice.ok.invoice.id,
        // refunding the full amount minus the fee
        amount: newInvoice.ok.invoice.amount - FEE,
        refundAccount: {
          text: "cd60093cef12e11d7b8e791448023348103855f682041e93f7d0be451f48118b".toUpperCase(),
        },
      });
      expect(refund.err).toBeTruthy();
    });
  });
  describe("already completed Invoice", () => {
    it("should return AlreadyVerified if an invoice has already been verified", async () => {
      let verifyResult = await defaultActor.verify_invoice({
        id: createResult.ok.invoice.id,
      });
      expect(verifyResult.ok.AlreadyVerified).toBeTruthy();
    });
  });
  /**
   * Transfer Tests
   */
  describe("Transfer Tests", () => {
    it("should increase a caller's icp balance after transferring to that account", async () => {
      resetBalance(); //?
      let destination = await defaultActor.get_account_identifier({
        token: { symbol: "ICP" },
        principal: defaultIdentity.getPrincipal(),
      });
      let transferResult = await balanceHolder.transfer({
        amount: 1000000n,
        token: {
          symbol: "ICP",
        },
        destination: destination.ok.accountIdentifier,
      });
      if ("ok" in transferResult) {
        let newBalance = await defaultActor.get_balance({
          token: {
            symbol: "ICP",
          },
        });
        expect(newBalance).toStrictEqual({ ok: { balance: 1000000n - FEE } });
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
        err: {
          kind: { InvalidDestination: null },
          message: ["Invalid account identifier"],
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
      expect(transferResult.err).toBeTruthy();
    });
  });
});
