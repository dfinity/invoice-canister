import A          "./Account";
import Hex        "./Hex";
import ICP        "./ICPLedger";
import T          "./Types";
import U          "./Utils";

import Array      "mo:base/Array";
import Blob       "mo:base/Blob";
import Cycles     "mo:base/ExperimentalCycles";
import Hash       "mo:base/Hash";
import HashMap    "mo:base/HashMap";
import Iter       "mo:base/Iter";
import Nat        "mo:base/Nat";
import Nat64      "mo:base/Nat64";
import Option     "mo:base/Option";
import Principal  "mo:base/Principal";
import Text       "mo:base/Text";
import Time       "mo:base/Time";

actor Invoice {
// #region Types
  type Details = T.Details;
  type Token = T.Token;
  type TokenVerbose = T.TokenVerbose;
  type AccountIdentifier = T.AccountIdentifier;
  type Invoice = T.Invoice;
// #endregion

  let errInvalidToken =
    #err({
       message = ?"This token is not yet supported. Currently, this canister supports ICP.";
       kind = #InvalidToken;
    });

/**
* Application State
*/

// #region State
  stable var invoiceCounter : Nat = 0;
  stable var entries : [(Nat, Invoice)] = [];
  var invoices : HashMap.HashMap<Nat, Invoice> = HashMap.HashMap(16, Nat.equal, Hash.hash);
// #endregion

/**
* Application Interface
*/

// #region Create Invoice
  public shared ({caller}) func create_invoice (args : T.CreateInvoiceArgs) : async T.CreateInvoiceResult {
    let id : Nat = invoiceCounter;
    // increment counter
    invoiceCounter += 1;

    let destinationResult : T.GetDestinationAccountIdentifierResult = getDestinationAccountIdentifier({
      token = args.token;
      invoiceId = id;
      caller
    });

    switch(destinationResult){
      case (#err result) {
        #err({
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
          permissions = args.permissions;
          amount = args.amount;
          amountPaid = 0;
          token;
          verifiedAtTime = null;
          refundedAtTime = null;
          paid = false;
          refunded = false;
          // 1 week in nanoseconds
          expiration = Time.now() + (1000 * 60 * 60 * 24 * 7 * 1_000_000);
          destination;
          refundAccount = null;
        };

        invoices.put(id, invoice);

        #ok({invoice});
      };
    };
  };

  func getTokenVerbose(token : Token) : TokenVerbose {
    switch(token.symbol){
      case ("ICP") {
        {
          symbol = "ICP";
          decimals = 8;
          meta = ?{
            Issuer = "e8s";
          }
        };

      };
      case (_) {
        {
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
  func getDestinationAccountIdentifier (args : T.GetDestinationAccountIdentifierArgs) : T.GetDestinationAccountIdentifierResult {
    let token = args.token;
    switch (token.symbol) {
      case "ICP" {
        let canisterId = Principal.fromActor(Invoice);

        let account = U.getICPAccountIdentifier({
          principal = canisterId;
          subaccount = U.generateInvoiceSubaccount({
            caller = args.caller;
            id = args.invoiceId;
          });
        });
        let hexEncoded = Hex.encode(Blob.toArray(account));
        let result : AccountIdentifier = #text(hexEncoded);
        #ok({accountIdentifier = result});
      };
      case _ {
        errInvalidToken;
      };
    };
  };
// #endregion
// #endregion

// #region Get Invoice
  public shared query ({caller}) func get_invoice (args : T.GetInvoiceArgs) : async T.GetInvoiceResult {
    let invoice = invoices.get(args.id);
    switch invoice {
      case null {
        #err({
          message = ?"Invoice not found";
          kind = #NotFound;
        });
      };
      case (?i) {
        if (i.creator == caller) {
          return #ok({invoice = i});
        };
        // If additional permissions are provided
        switch (i.permissions) {
          case (null) {
            return #err({
              message = ?"You do not have permission to view this invoice";
              kind = #NotAuthorized;
            });
          };
          case (?permissions) {
            let hasPermission = Array.find<Principal>(
              permissions.canGet,
              func (x : Principal) : Bool {
                return x == caller;
              }
            );
            if (Option.isSome(hasPermission)) {
              return #ok({invoice = i});
            } else {
              return #err({
                message = ?"You do not have permission to view this invoice";
                kind = #NotAuthorized;
              });
            };
          };
        };
        #ok({invoice = i});
      };
    };
  };
// #endregion

// #region Get Balance
  public shared ({caller}) func get_balance (args : T.GetBalanceArgs) : async T.GetBalanceResult {
    let token = args.token;
    let canisterId = Principal.fromActor(Invoice);
    switch (token.symbol) {
      case "ICP" {
        let defaultAccount = Hex.encode(
          Blob.toArray(
            U.getDefaultAccount({
              canisterId;
              principal = caller;
            })
         )
        );
        let balance = await ICP.balance({account = defaultAccount});
        switch(balance) {
          case (#err err) {
            #err({
              message = ?"Could not get balance";
              kind = #NotFound;
            });
          };
          case (#ok result){
            #ok({balance = result.balance});
          };
        };
      };
      case _ {
        errInvalidToken;
      };
    };
  };
// #endregion

// #region Verify Invoice
  public shared ({caller}) func verify_invoice (args : T.VerifyInvoiceArgs) : async T.VerifyInvoiceResult {
    let invoice = invoices.get(args.id);
    let canisterId = Principal.fromActor(Invoice);

    switch invoice {
      case null{
        #err({
          message = ?"Invoice not found";
          kind = #NotFound;
        });
      };
      case (?i) {
        // Return if already verified
        if (i.verifiedAtTime != null) {
          return #ok(#AlreadyVerified {
            invoice = i;
          });
        };
        if (i.creator != caller) {
          switch (i.permissions) {
            case null {
              return #err({
                message = ?"You do not have permission to verify this invoice";
                kind = #NotAuthorized;
              });
            };
            case (?permissions) {
              let hasPermission = Array.find<Principal>(
                permissions.canVerify,
                func (x : Principal) : Bool {
                  return x == caller;
                }
              );
              if (Option.isSome(hasPermission)) {
                // May proceed
              } else {
                return #err({
                  message = ?"You do not have permission to verify this invoice";
                  kind = #NotAuthorized;
                });
              };
            };
          };
        };

        switch (i.token.symbol) {
          case "ICP" {
            let result : T.VerifyInvoiceResult = await ICP.verifyInvoice({
              invoice = i;
              caller;
              canisterId;
            });
            switch result {
              case (#ok value) {
                switch (value) {
                  case (#AlreadyVerified _) { };
                  case (#Paid paidResult) {
                    let replaced = invoices.replace(i.id, paidResult.invoice);
                  };
                };
              };
              case (#err _) {};
            };
            result;
          };
          case _ {
            errInvalidToken;
          };
        };
      };
    };
  };
// #endregion

// #region Refund Invoice
  public shared ({caller}) func refund_invoice (args : T.RefundInvoiceArgs) : async T.RefundInvoiceResult {
    let canisterId = Principal.fromActor(Invoice);

    let accountResult = U.accountIdentifierToBlob({
      accountIdentifier = args.refundAccount;
      canisterId = ?canisterId;
    });
    switch(accountResult){
      case(#err err){
        #err({
          message = err.message;
          kind = #InvalidDestination;
        });
      };
      case (#ok destination) {
        let invoice = invoices.get(args.id);
        switch invoice {
          case null {
            #err({
              message = ?"Invoice not found";
              kind = #NotFound;
            });
          };
          case (?i) {
            // Return if caller was not the creator
            if (i.creator != caller) {
              return #err({
                message = ?"Only the creator of the invoice can issue a refund";
                kind = #NotAuthorized;
              });
            };
            // Return if refund amount is greater than the invoice amountPaid
            if (args.amount > i.amountPaid) {
              return #err({
                message = ?"Refund amount cannot be greater than the amount paid";
                kind = #InvalidAmount;
              });
            };
            // Return if already refunded
            if (i.refundedAtTime != null) {
              return #err({
                message = ?"Invoice already refunded";
                kind = #AlreadyRefunded;
              });
            };
            switch (i.token.symbol) {
              case "ICP" {
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
                switch transferResult {
                  case (#ok result) {
                    let updatedInvoice = {
                      id = i.id;
                      creator = i.creator;
                      details = i.details;
                      permissions = i.permissions;
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
                    #ok(result);
                  };
                  case (#err err) {
                    switch (err.kind) {
                      case (#BadFee f) {
                        #err({
                          message = err.message;
                          kind = #BadFee;
                        });
                      };
                      case (#InsufficientFunds f) {
                        #err({
                          message = err.message;
                          kind = #InsufficientFunds;
                        });
                      };
                      case _ {
                        #err({
                          message = err.message;
                          kind = #Other;
                        });
                      }
                    };
                  };
                };
              };
              case _ {
                errInvalidToken;
              };
            }
          };
        };
      };
    };
  };
// #endregion

// #region Transfer
  public shared ({caller}) func transfer (args : T.TransferArgs) : async T.TransferResult {
    let token = args.token;
    let accountResult = U.accountIdentifierToBlob({
      accountIdentifier = args.destination;
      canisterId = ?Principal.fromActor(Invoice);
    });
    switch (accountResult) {
      case (#err err) {
        #err({
          message = err.message;
          kind = #InvalidDestination;
        });
      };
      case (#ok destination) {
        switch (token.symbol) {
          case "ICP" {
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
                #ok(result);
              };
              case (#err err) {
                switch (err.kind) {
                  case (#BadFee _) {
                    #err({
                      message = err.message;
                      kind = #BadFee;
                    });
                  };
                  case (#InsufficientFunds _) {
                    #err({
                      message = err.message;
                      kind = #InsufficientFunds;
                    });
                  };
                  case _ {
                    #err({
                      message = err.message;
                      kind = #Other;
                    });
                  }
                };
              };
            };
          };
          case _ {
            errInvalidToken;
          };
        };
      };
    };
  };
// #endregion

// #region get_account_identifier
  /*
    * Get Caller Identifier
    * Allows a caller to the accountIdentifier for a given principal
    * for a specific token.
    */
  public query func get_account_identifier (args : T.GetAccountIdentifierArgs) : async T.GetAccountIdentifierResult {
    let token = args.token;
    let principal = args.principal;
    let canisterId = Principal.fromActor(Invoice);
    switch (token.symbol) {
      case "ICP" {
        let subaccount = U.getDefaultAccount({principal; canisterId;});
        let hexEncoded = Hex.encode(
          Blob.toArray(subaccount)
        );
        let result : AccountIdentifier = #text(hexEncoded);
        #ok({accountIdentifier = result});
      };
      case _ {
        errInvalidToken;
      };
    };
  };
// #endregion

// #region Utils
  public query func remaining_cycles() : async Nat {
    Cycles.balance()
  };

  public func accountIdentifierToBlob (accountIdentifier : AccountIdentifier) : async T.AccountIdentifierToBlobResult {
    U.accountIdentifierToBlob({
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
