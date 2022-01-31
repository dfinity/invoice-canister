import A "./Account";
import T "./Types";
import U "./Utils";
import Hex "./Hex";
import CRC32     "./CRC32";
import SHA256 "./SHA256";
import SHA224    "./SHA224";
import ICP "./ICPLedger";
import Prim "mo:⛔";

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import error "mo:base/error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";

actor Invoice {
// #region Types
  type Details = T.Details;
  type Token = T.Token;
  type TokenVerbose = T.TokenVerbose;
  type AccountIdentifier = T.AccountIdentifier;
  type Invoice = T.Invoice;
// #endregion

/**
* Application State
*/

// #region State
  stable var invoiceCounter : Nat = 0;
  stable var entries : [(Nat, Invoice)] = [];
  var invoices: HashMap.HashMap<Nat, Invoice> = HashMap.HashMap(16, Nat.equal, Hash.hash);
// #endregion

/**
* Application Interface
*/    

// #region Create Invoice
  public shared ({caller}) func create_invoice (args: T.CreateInvoiceArgs) : async T.CreateInvoiceResult {
    let id : Nat = invoiceCounter;
    // increment counter
    invoiceCounter += 1;

    let destinationResult : T.GetDestinationAccountIdentifierResult = getDestinationAccountIdentifier({ 
      token=args.token;
      invoiceId=id;
      caller 
    });

    switch(destinationResult){
      case (#err result) {
        return #err({
          message = ?"Invalid destination account identifier";
          kind = #InvalidDestination;
        });
      };
      case (#ok result) {
        let destination : AccountIdentifier = result.accountIdentifier;
        let token = getTokenVerbose(args.token);

        let invoice : Invoice = {
          id;
          creator = caller;
          details = args.details;
          amount = args.amount;
          amountPaid = 0;
          token;
          verifiedAtTime = null;
          refundedAtTime = null;
          paid = false;
          refunded = false;
          // 1 week in nanoseconds
          expiration = Time.now() + (1000 * 60 * 60 * 24 * 7);
          destination;
          refundAccount = null;
        };
    
        invoices.put(id, invoice);

        return #ok({invoice});
      };
    };
  };

  func getTokenVerbose(token: Token) : TokenVerbose { 
    switch(token.symbol){
      case ("ICP") {
        return {
          symbol = "ICP";
          decimals = 8;
          meta = ?{
            Issuer = "e8s";
          }
        };

      };
      case (_) {
        return {
          symbol = "";
          decimals = 1;
          meta = ?{
            Issuer = "";
          }
        }
      };
    };
  };

// #region Get Destination Account Identifier
  func getDestinationAccountIdentifier (args: T.GetDestinationAccountIdentifierArgs) : T.GetDestinationAccountIdentifierResult {
    let token = args.token;
    switch(token.symbol){
      case("ICP"){
        let canisterId = Principal.fromActor(Invoice);

        let account = ICP.getICPAccountIdentifier({
          principal = canisterId;
          subaccount = U.generateInvoiceSubaccount({ 
            caller = args.caller;
            id = args.invoiceId;
          });
        });
        let hexEncoded = Hex.encode(Blob.toArray(account));
        let result: AccountIdentifier = #text(hexEncoded);
        return #ok({accountIdentifier = result});
      };
      case(_){
        return #err({
          message = ?"This token is not yet supported. Currently, this canister supports ICP.";
          kind = #InvalidToken;
        });
      };
    };
  };
// #endregion
// #endregion

// #region Get Invoice
  public func get_invoice (args: T.GetInvoiceArgs) : async T.GetInvoiceResult {
    let invoice = invoices.get(args.id);
    switch(invoice){
      case(null){
        return #err({
          message = ?"Invoice not found";
          kind = #NotFound;
        });
      };
      case(? i){
        return #ok({invoice = i});
      };
    };
  };
// #endregion

// #region Get Balance
  public shared ({caller}) func get_balance (args: T.GetBalanceArgs) : async T.GetBalanceResult {
    let token = args.token;
    let canisterId = Principal.fromActor(Invoice);
    switch(token.symbol){
      case("ICP"){
        let defaultAccount = Hex.encode(Blob.toArray(ICP.getDefaultAccount({caller; canisterId})));
        let balance = await ICP.balance({account = defaultAccount});
        switch(balance){
          case(#err err){
            return #err({
              message = ?"Could not get balance";
              kind = #NotFound;
            });
          };
          case(#ok result){
            return #ok({balance = result.balance});
          };
        };
      };
      case(_){
        return #err({
          message = ?"This token is not yet supported. Currently, this canister supports ICP.";
          kind = #InvalidToken;
        });
      };
    };
  };
// #endregion

// #region Verify Invoice
  public shared ({caller}) func verify_invoice (args: T.VerifyInvoiceArgs) : async T.VerifyInvoiceResult {
    let invoice = invoices.get(args.id);
    let canisterId = Principal.fromActor(Invoice);

    switch(invoice){
      case(null){
        return #err({
          message = ?"Invoice not found";
          kind = #NotFound;
        });
      };
      case(? i){
        // Return if already verified
        if (i.verifiedAtTime != null){
          return #ok(#AlreadyVerified{
            invoice = i;
          });
        };

        switch (i.token.symbol){
          case("ICP"){
            let result: T.VerifyInvoiceResult = await ICP.verifyInvoice({
              invoice = i;
              caller;
              canisterId;
            });
            switch (result){
              case(#ok value){
                switch (value){
                  case(#AlreadyVerified _){};
                  case(#Paid paidResult){
                    let replaced = invoices.replace(i.id, paidResult.invoice);
                  };
                };
              };
              case(#err _){};
            };
            return result;
          };
          case(_){
            return #err({
              message = ?"This token is not yet supported. Currently, this canister supports ICP.";
              kind = #InvalidToken;
            });
          };
        };
      };
    };
  };
// #endregion

// #region Refund Invoice
  public shared ({caller}) func refund_invoice (args : T.RefundInvoiceArgs) : async T.RefundInvoiceResult {
    let canisterId = Principal.fromActor(Invoice);
    let invoice = invoices.get(args.id);

    let accountResult = U.accountIdentifierToBlob({
      accountIdentifier = args.refundAccount;
      canisterId = ?canisterId;
    });
    switch(accountResult){
      case(#err err){
        return #err({
          message = err.message;
          kind = #InvalidDestination;
        });
      };
      case (#ok destination){
        let invoice = invoices.get(args.id);
        switch (invoice){
          case(null){
            return #err({
              message = ?"Invoice not found";
              kind = #NotFound;
            });
          };
          case(? i){
            // Return if already refunded
            if (i.refundedAtTime != null){
              return #err({
                message = ?"Invoice already refunded";
                kind = #AlreadyRefunded;
              });
            };
            switch(i.token.symbol){
              case("ICP"){
                let transferResult = await ICP.transfer({
                  memo = 0;
                  fee = {
                    e8s = 10000;
                  };
                  amount = {
                    // Total amount, minus the fee
                    e8s = Nat64.sub(Nat64.fromNat(args.amount), 10000);
                  };
                  from_subaccount = ?A.principalToSubaccount(caller);
                  to = destination;
                  created_at_time = null;
                });
                switch (transferResult) {
                  case (#ok result) {
                    let updatedInvoice = {
                      id = i.id;
                      creator = i.creator;
                      details = i.details;
                      amount = i.amount;
                      amountPaid = i.amountPaid;
                      token = i.token;
                      verifiedAtTime = i.verifiedAtTime;
                      refundedAtTime = ?Time.now();
                      paid = i.paid;
                      refunded = true;
                      expiration = i.expiration;
                      destination = i.destination;
                      refundAccount = ?#blob(destination);
                    };
                    let replaced = invoices.put(i.id, updatedInvoice);
                    return #ok(result);
                  };
                  case (#err err) {
                    switch (err.kind){
                      case (#BadFee f){
                        return #err({
                          message = err.message;
                          kind = #BadFee;
                        });
                      };
                      case (#InsufficientFunds f){
                        return #err({
                          message = err.message;
                          kind = #InsufficientFunds;
                        });
                      };
                      case (_){
                        return #err({
                          message = err.message;
                          kind = #Other;
                        });
                      }
                    };
                  };
                };
              };
              case(_){
                return #err({
                  message = ?"This token is not yet supported. Currently, this canister supports ICP.";
                  kind = #InvalidToken;
                });
              };
            }
          };
        };
      };
    };
  };
// #endregion

// #region Transfer
  public shared ({caller}) func transfer (args: T.TransferArgs) : async T.TransferResult {
    let token = args.token;
    let accountResult = U.accountIdentifierToBlob({
      accountIdentifier = args.destination;
      canisterId = ?Principal.fromActor(Invoice);
    });
    switch (accountResult){
      case (#err err){
        return #err({
          message = err.message;
          kind = #InvalidDestination;
        });
      };
      case (#ok destination){
        switch(token.symbol){
          case("ICP"){
            let now = Nat64.fromIntWrap(Time.now());
            

            let transferResult = await ICP.transfer({
              memo = 0;
              fee = {
                e8s = 10000;
              };
              amount = {
                // Total amount, minus the fee
                e8s = Nat64.sub(Nat64.fromNat(args.amount), 10000);
              };
              from_subaccount = ?A.principalToSubaccount(caller);

              to = destination;
              created_at_time = null;
            });
            switch (transferResult) {
              case (#ok result) {
                return #ok(result);
              };
              case (#err err) {
                switch (err.kind){
                  case (#BadFee _){
                    return #err({
                      message = err.message;
                      kind = #BadFee;
                    });
                  };
                  case (#InsufficientFunds _){
                    return #err({
                      message = err.message;
                      kind = #InsufficientFunds;
                    });
                  };
                  case (_){
                    return #err({
                      message = err.message;
                      kind = #Other;
                    });
                  }
                };
              };
            };
          };
          case(_){
            return #err({
              message = ?"Token not supported";
              kind = #InvalidToken;
            });
          };
        };
      };
    };
  };
// #endregion

// #region get_caller_identifier
  /*
    * Get Caller Identifier
    * Allows a caller to get their own account identifier
    * for a specific token.
    */
  public shared query ({caller}) func get_caller_identifier (args: T.GetCallerIdentifierArgs) : async T.GetCallerIdentifierResult {
    let token = args.token;
    let canisterId = Principal.fromActor(Invoice);
    switch(token.symbol){
      case("ICP"){
        let subaccount = ICP.getDefaultAccount({caller; canisterId;});
        let hexEncoded = Hex.encode(
          Blob.toArray(subaccount)
        );
        let result: AccountIdentifier = #text(hexEncoded);
        return #ok({accountIdentifier = result});
      };
      case(_){
        return #err({
          message = ?"This token is not yet supported. Currently, this canister supports ICP.";
          kind = #InvalidToken;
        });
      };
    };
  };
// #endregion

// #region Utils
  public query func remaining_cycles() : async Nat {
    return Cycles.balance()
  };
  public func accountIdentifierToBlob (accountIdentifier: AccountIdentifier) : async T.AccountIdentifierToBlobResult {
    return U.accountIdentifierToBlob({
      accountIdentifier;
      canisterId = ?Principal.fromActor(Invoice);
    });
  };
// #endregion

// #region Upgrade Hooks
  system func preupgrade() {
      entries := Iter.toArray(invoices.entries());
  };

  system func postupgrade() {
      invoices := HashMap.fromIter(Iter.fromArray(entries), 16, Nat.equal, Hash.hash);
      entries := [];
  };
// #endregion
}
