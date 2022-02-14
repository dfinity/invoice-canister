import A          "../../../../src/invoice/Account";   
import Hex        "../../../../src/invoice/Hex";
import T          "../../../../src/invoice/Types";
import U          "../../../../src/invoice/Utils";

import Blob       "mo:base/Blob";
import Cycles     "mo:base/ExperimentalCycles";
import Debug      "mo:base/Debug";
import Hash       "mo:base/Hash";
import HashMap    "mo:base/HashMap";
import Iter       "mo:base/Iter";
import Nat        "mo:base/Nat";
import Nat64      "mo:base/Nat64";
import Principal  "mo:base/Principal";
import Result     "mo:base/Result";
import Text       "mo:base/Text";
import Time       "mo:base/Time";

actor InvoiceMock {
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

  var icpBlockHeight : Nat = 0;
  var icpLedgerMock : HashMap.HashMap<Blob, Nat> = HashMap.HashMap(16, Blob.equal, Blob.hash);
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
          permissions = args.permissions;
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
        let canisterId = Principal.fromActor(InvoiceMock);

        let account = U.getICPAccountIdentifier({
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
    let canisterId = Principal.fromActor(InvoiceMock);
    switch(token.symbol){
      case("ICP"){
        let defaultAccount = U.getDefaultAccount({
          canisterId;
          principal = caller;
        });
        let balance = icpLedgerMock.get(defaultAccount);
        switch(balance){
          case(null){
            return #err({
              message = ?"Could not get balance";
              kind = #NotFound;
            });
          };
          case(? b){
            return #ok({balance = b});
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
    let canisterId = Principal.fromActor(InvoiceMock);

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
            let destinationResult = U.accountIdentifierToBlob({
              accountIdentifier = i.destination;
              canisterId = ?canisterId;
              });
            switch(destinationResult){
              case(#err err){
                return #err({
                  kind = #InvalidAccount;
                  message = ?"Invalid destination account";
                });
              };
              case (#ok destination){
                let destinationBalance = icpLedgerMock.get(destination);
                switch(destinationBalance){
                  case (null){
                    return #err({
                      message = ?"Insufficient balance. Current Balance is 0";
                      kind = #NotYetPaid;
                    });
                  };
                  case (? balance){
                    if(balance < i.amount){
                      return #err({
                        message = ?Text.concat("Insufficient balance. Current Balance is ", Nat.toText(balance));
                        kind = #NotYetPaid;
                      });
                    };
                    let verifiedAtTime: ?Time.Time = ?Time.now();
                    // Otherwise, update with latest balance and mark as paid
                    let verifiedInvoice = {
                      id = i.id;
                      creator = i.creator;
                      details = i.details;
                      permissions = i.permissions;
                      amount = i.amount;
                      // update amountPaid
                      amountPaid = balance;
                      token = i.token;
                      // update verifiedAtTime
                      verifiedAtTime;
                      refundedAtTime = i.refundedAtTime;
                      // update paid
                      paid = true;
                      refunded = false;
                      expiration = i.expiration;
                      destination = i.destination;
                      refundAccount = i.refundAccount;
                    };

                    // TODO Transfer funds to default subaccount of invoice creator
                    let subaccount = U.generateInvoiceSubaccount({ caller = i.creator; id = i.id });
                    let transfer = await mockICPTransfer({
                      amount = {
                        e8s = Nat64.fromNat(balance - 10_000);
                      };
                      fee = {
                        e8s = 10_000;
                      };
                      memo = 0;
                      from_subaccount = ?subaccount;
                      to = #blob(U.getDefaultAccount({
                        canisterId;
                        principal = i.creator;
                      }));
                      token = i.token;
                      canisterId = ?canisterId;
                      created_at_time = null;
                    });
                    let replaced = invoices.replace(i.id, verifiedInvoice);
                    return #ok(#Paid({
                      invoice = verifiedInvoice;
                    }));
                  };
                };

              };
            }
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
    let canisterId = Principal.fromActor(InvoiceMock);

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
            // Return if caller was not the creator
            if (i.creator != caller){
              return #err({
                message = ?"Only the creator of the invoice can issue a refund";
                kind = #NotAuthorized;
              });
            };
            // Return if refund amount is greater than the invoice amountPaid
            if (args.amount > i.amountPaid){
              return #err({
                message = ?"Refund amount cannot be greater than the amount paid";
                kind = #InvalidAmount;
              });
            };
            // Return if already refunded
            if (i.refundedAtTime != null){
              return #err({
                message = ?"Invoice already refunded";
                kind = #AlreadyRefunded;
              });
            };
            switch(i.token.symbol){
              case("ICP"){
                let transferResult = await mockICPTransfer({
                  memo = 0;
                  fee = {
                    e8s = 10000;
                  };
                  amount = {
                    // Total amount, minus the fee
                    e8s = Nat64.sub(Nat64.fromNat(args.amount), 10000);
                  };
                  from_subaccount = ?A.principalToSubaccount(caller);
                  to = #blob(destination);
                  created_at_time = null;
                });
                switch (transferResult) {
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
      canisterId = ?Principal.fromActor(InvoiceMock);
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
            

            let transferResult = await mockICPTransfer({
              memo = 0;
              fee = {
                e8s = 10000;
              };
              amount = {
                // Total amount, minus the fee
                e8s = Nat64.sub(Nat64.fromNat(args.amount), 10000);
              };
              from_subaccount = ?A.principalToSubaccount(caller);

              to = #blob(destination);
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

// #region get_account_identifier
  /*
    * Get Caller Identifier
    * Allows a caller to the accountIdentifier for a given principal
    * for a specific token.
    */
  public query func get_account_identifier (args: T.GetAccountIdentifierArgs) : async T.GetAccountIdentifierResult {
    let token = args.token;
    let principal = args.principal;
    let canisterId = Principal.fromActor(InvoiceMock);
    switch(token.symbol){
      case("ICP"){
        let subaccount = U.getDefaultAccount({principal; canisterId;});
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
      canisterId = ?Principal.fromActor(InvoiceMock);
    });
  };
  
  func mockICPTransfer (args: T.ICPTransferArgs) : async T.ICPTransferResult {
    let FEE = 10_000;
    let amount = args.amount;
    switch(args.from_subaccount){
      case(? subaccount){
        let fromAccount = U.getICPAccountIdentifier({
          subaccount;
          principal = Principal.fromActor(InvoiceMock);
        });
        let balance = icpLedgerMock.get(fromAccount);
        switch(balance){
          case(? b){
            if(b < Nat64.toNat(amount.e8s) + FEE){
              Debug.trap("InsufficientFunds");
            };
            let newBalance = Nat.sub(Nat.sub(b, Nat64.toNat(amount.e8s)), FEE);
            icpLedgerMock.put(fromAccount, newBalance);
            
            let destinationResult = U.accountIdentifierToBlob({
              accountIdentifier = args.to;
              canisterId = ?Principal.fromActor(InvoiceMock);
            });
            switch(destinationResult){
              case(#err err){
                switch(err.message){
                  case (null){
                    Debug.trap("InvalidDestination");
                  };
                  case(? message){
                    Debug.trap(message);
                  };
                }
              };
              case (#ok destination){
                let destinationBalance = icpLedgerMock.get(destination);
                let newDestinationBalance = newBalance + Nat64.toNat(amount.e8s);
                icpLedgerMock.put(destination, newDestinationBalance);
                icpBlockHeight := icpBlockHeight + 1;
                return #ok({
                  blockHeight = Nat64.fromNat(icpBlockHeight);
                });

              };
            };
          };
          case(_){
            Debug.trap("InsufficientFunds");
          };
        };
      };
      case(null){
        Debug.trap("InvalidSubaccount");
      };
    };
  };

  // Useful for testing
  type FreeMoneyArgs = {
    amount: Nat;
    accountIdentifier: AccountIdentifier;
  };
  type FreeMoneyResult = Result.Result<Nat, FreeMoneyError>;
  type FreeMoneyError = {
    message: ?Text;
    kind: {
      #InvalidDestination;
    };
  };
  public func deposit_free_money (args: FreeMoneyArgs) : async FreeMoneyResult {
    let amount = args.amount;
    let accountBlob = U.accountIdentifierToBlob({
      accountIdentifier = args.accountIdentifier;
      canisterId = ?Principal.fromActor(InvoiceMock);
    });
    
    switch(accountBlob){
      case(#err err){
        return #err({
          message = err.message;
          kind = #InvalidDestination;
        });
      };
      case(#ok account){
        let balanceResult = icpLedgerMock.get(account);
        switch(balanceResult){
          case(null){
            icpLedgerMock.put(account, amount);
            return #ok(amount);
          };
          case (? balance){
            let newBalance = balance + amount;
            icpLedgerMock.put(account, newBalance);
            return #ok(newBalance);
          };
        };
      };
    };
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
