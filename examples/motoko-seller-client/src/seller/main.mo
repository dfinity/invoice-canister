import Invoice "canister:invoice";

import Cycles     "mo:base/ExperimentalCycles";
import HashMap    "mo:base/HashMap";
import Iter       "mo:base/Iter";
import Principal  "mo:base/Principal";
import Result     "mo:base/Result";
import Text       "mo:base/Text";

actor Seller {

  let ONE_ICP_IN_E8S = 100_000_000;

  stable var invoicesStable : [(Principal, Invoice.Invoice)] = [];
  var invoices: HashMap.HashMap<Principal, Invoice.Invoice> = HashMap.HashMap(16, Principal.equal, Principal.hash);

  stable var licensesStable : [(Principal, Bool)] = [];
  var licenses: HashMap.HashMap<Principal, Bool> = HashMap.HashMap(16, Principal.equal, Principal.hash);

// #region create_invoice
  public shared ({caller}) func create_invoice() : async Invoice.CreateInvoiceResult {
    let invoiceCreateArgs : Invoice.CreateInvoiceArgs = {
      amount = ONE_ICP_IN_E8S / 10;
      token = {
        symbol = "ICP";
      };
      permissions = null;
      details = ?{
        description = "Example license certifying status";
        // JSON string as a blob
        meta = Text.encodeUtf8(
          "{\n" #
          "  \"seller\": \"Invoice Canister Example Dapp\",\n" #
          "  \"itemized_bill\": [\"Standard License\"],\n" #
          "}"
        );
      };
    };
    let invoiceResult = await Invoice.create_invoice(invoiceCreateArgs);
    switch(invoiceResult){
      case(#err _) {};
      case(#ok result) {
        invoices.put(caller, result.invoice);
      };
    };
    return invoiceResult;
  };

  public shared query ({caller}) func check_license_status() : async Bool {
    let licenseResult = licenses.get(caller);
    switch(licenseResult) {
      case(null){
        return false;
      };
      case (? license){
        return license;
      };
    };
  };

  public shared query ({caller}) func get_invoice() : async ?Invoice.Invoice {
    invoices.get(caller);
  };

  public shared ({caller}) func verify_invoice() : async Invoice.VerifyInvoiceResult {
    let invoiceResult = invoices.get(caller);
    switch(invoiceResult){
      case(null){
        return #err({
          kind = #Other;
          message = ?"Invoice not found for this user";
        });
      };
      case (? invoice){
        let verifyResult = await Invoice.verify_invoice({id = invoice.id});
        if (Result.isOk(verifyResult)){
          // update invoices with the verified invoice
          invoices.put(caller, invoice);

          // update licenses with the verified invoice
          licenses.put(caller, true);
        };
        return verifyResult;
      };
    };
  };

// #region Utils
  public query func remaining_cycles() : async Nat {
    return Cycles.balance()
  };
// #endregion

// #region Upgrade Hooks
  system func preupgrade() {
      invoicesStable := Iter.toArray(invoices.entries());
      licensesStable := Iter.toArray(licenses.entries());
  };

  system func postupgrade() {
      invoices := HashMap.fromIter(Iter.fromArray(invoicesStable), 16, Principal.equal, Principal.hash);
      invoicesStable := [];
      licenses := HashMap.fromIter(Iter.fromArray(licensesStable), 16, Principal.equal, Principal.hash);
      licensesStable := [];
  };
// #endregion
};
