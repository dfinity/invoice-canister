import A "./Account";
import T "./Types";
import U "./Utils";
import Hex "./Hex";
import CRC32     "./CRC32";
import SHA256 "./SHA256";
import SHA224    "./SHA224";
import SelfMeta "./SelfMeta";
import ICP "./ICPLedger";
import Prim "mo:⛔";

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
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
    type CreateInvoiceArgs = {
        amount: Nat;
        token: Token;
        details: ?Details;
        refundAccount: ?AccountIdentifier;
    };
    type CreateInvoiceResult = {
        #Ok: CreateInvoiceSuccess;
        #Err: CreateInvoiceErr;
    };
    type CreateInvoiceSuccess = {
        invoice: Invoice;
    };
    type CreateInvoiceErr = {
        message: ?Text; 
        kind: {
            #InvalidToken;
            #InvalidAmount;
            #InvalidDestination;
            #InvalidDetails;
            #InvalidRefundAccount;
        };
    };
    public shared ({caller}) func create_invoice (args: CreateInvoiceArgs) : async CreateInvoiceResult {
        let id : Nat = invoiceCounter;
        // increment counter
        invoiceCounter += 1;

        let destinationResult : GetDestinationAccountIdentifierResult = getDestinationAccountIdentifier({ 
            token=args.token;
            invoiceId=id;
            caller 
        });

        switch(destinationResult){
            case (#Err result) {
                return #Err({
                    message = ?"Invalid destination account identifier";
                    kind = #InvalidDestination;
                });
            };
            case (#Ok result) {
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
                    paid = false;
                    refunded = false;
                    // 1 week in nanoseconds
                    expiration = Time.now() + (1000 * 60 * 60 * 24 * 7);
                    destination;
                    refundAccount = args.refundAccount;
                };
                
                invoices.put(id, invoice);

                #Ok({invoice});
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
    type GetDestinationAccountIdentifierArgs = {
        token : Token;
        caller : Principal;
        invoiceId : Nat;
    };
    type GetDestinationAccountIdentifierResult = {
        #Ok: GetDestinationAccountIdentifierSuccess;
        #Err: GetDestinationAccountIdentifierErr;
    };
    type GetDestinationAccountIdentifierSuccess = {
        accountIdentifier: AccountIdentifier;
    };
    type GetDestinationAccountIdentifierErr = {
        message: ?Text; 
        kind: {
            #InvalidToken;
            #InvalidInvoiceId;
        };
    };

    func getDestinationAccountIdentifier (args: GetDestinationAccountIdentifierArgs) : GetDestinationAccountIdentifierResult {
        let token = args.token;
        switch(token.symbol){
            case("ICP"){
                let meta : SelfMeta.Meta = SelfMeta.getMeta();
                let canisterId = meta.canisterId;

                let account = ICP.getICPAccountIdentifier({
                    principal = canisterId;
                    subaccount = U.generateInvoiceId({ 
                        caller = args.caller;
                        id = args.invoiceId;
                    });
                });
                let hexEncoded = Hex.encode(Blob.toArray(account));
                let result: AccountIdentifier = #text(hexEncoded);
                #Ok({accountIdentifier = result});
            };
            case(_){
                #Err({
                    message = ?"This token is not yet supported. Currently, this canister supports ICP.";
                    kind = #InvalidToken;
                });
            };
        };
    };
// #endregion
// #endregion

// #region Get Invoice
    type GetInvoiceArgs = {
        id: Nat;
    };
    type GetInvoiceResult = {
        #Ok: GetInvoiceSuccess;
        #Err: GetInvoiceErr;
    };
    type GetInvoiceSuccess = {
        invoice: Invoice;
    };
    type GetInvoiceErr = {
        message: ?Text; 
        kind: {
            #InvalidInvoiceId;
            #NotFound;
        };
    };
    public func get_invoice (args: GetInvoiceArgs) : async GetInvoiceResult {
        let invoice = invoices.get(args.id);
        switch(invoice){
            case(null){
                return #Err({
                    message = ?"Invoice not found";
                    kind = #NotFound;
                });
            };
            case(? i){
                return #Ok({invoice = i});
            };
        };
    };
// #endregion

// #region Get Balance
    type GetBalanceArgs = {
	    token: Token;
    };
    type GetBalanceResult = {
        #Ok: GetBalanceSuccess;
        #Err: GetBalanceErr;
    };
    type GetBalanceSuccess = {
        balance: Nat;
    };
    type GetBalanceErr = {
        message: ?Text; 
        kind: {
            #InvalidToken;
            #NotFound;
        };
    };
    public shared ({caller}) func get_balance (args: GetBalanceArgs) : async GetBalanceResult {
        let token = args.token;
        switch(token.symbol){
            case("ICP"){
                let defaultAccount = Hex.encode(Blob.toArray(ICP.getDefaultAccount({caller})));
                let balance = await ICP.balance({account = defaultAccount});
                switch(balance){
                    case(#Err err){
                        #Err({
                            message = ?"Could not get balance";
                            kind = #NotFound;
                        });
                    };
                    case(#Ok result){
                        return #Ok({balance = result.balance});
                    };
                };
            };
            case(_){
                #Err({
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

        switch(invoice){
            case(null){
                return #Err({
                    message = ?"Invoice not found";
                    kind = #NotFound;
                });
            };
            case(? i){
                // Return if already verified
                if (i.verifiedAtTime != null){
                    return #Ok(#AlreadyVerified{
                        invoice = i;
                    });
                };

                switch (i.token.symbol){
                    case("ICP"){
                        let result: T.VerifyInvoiceResult = await ICP.verifyInvoice({
                            invoice = i;
                            caller = caller;
                        });
                        switch (result){
                            case(#Ok value){
                                switch (value){
                                    case(#AlreadyVerified _){};
                                    case(#Paid paidResult){
                                         let replaced = invoices.replace(i.id, paidResult.invoice);
                                    };
                                };
                            };
                            case(#Err _){};
                        };
                        return result;
                    };
                    case(_){
                        return #Err({
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
    public func refund_invoice () {
        // TODO
    };
// #endregion

// #region Transfer
    type TransferArgs = {
        amount: Nat;
        token: Token;
        destination: AccountIdentifier;
    };
    type TransferResult = {
        #Ok: TransferSuccess;
        #Err: TransferError;
    };
    type TransferSuccess = {
        blockHeight: Nat64;
    };
     type TransferError = {
        message: ?Text; 
        kind: {
            #BadFee;
            #InsufficientFunds;
            #InvalidToken;
            #Other;
        };
    };

    public shared ({caller}) func transfer (args: TransferArgs) : async TransferResult {
        let token = args.token;
        switch(token.symbol){
            case("ICP"){
                let now = Nat64.fromIntWrap(Time.now());
                let destination : ICP.AccountIdentifier = U.accountIdentifierToBlob(args.destination);

                let transferResult = await ICP.transfer({
                    memo = 0;
                    fee = {
                        e8s = 10000;
                    };
                    amount = {
                        // Total amount, minus the fee
                        e8s = Nat64.sub(Nat64.fromNat(args.amount), 10000);
                    };
                    from_subaccount = ?ICP.principalToSubaccount(caller);

                    to = U.accountIdentifierToBlob(args.destination);
                    created_at_time = null;
                });
                switch (transferResult) {
                    case (#Ok result) {
                        return #Ok({blockHeight = result});
                    };
                    case (#Err err) {
                        switch (err){
                            case (#BadFee f){
                                return #Err({
                                    message = ?"Bad fee";
                                    kind = #BadFee;
                                });
                            };
                            case (#InsufficientFunds f){
                                return #Err({
                                    message = ?"Insufficient funds";
                                    kind = #InsufficientFunds;
                                });
                            };
                            case (_){
                                return #Err({
                                    message = ?"Could not transfer funds to invoice creator.";
                                    kind = #Other;
                                });
                            }
                        };
                    };
                };
            };
            case(_){
                return #Err({
                    message = ?"Token not supported";
                    kind = #InvalidToken;
                });
            };
        };
        // TODO - future tokens
    };
// #endregion

// #region get_caller_identifier
    /*
     * Get Caller Identifier
     * Allows a caller to get their own account identifier
     * for a specific token.
     */
    type GetCallerIdentifierArgs = {
        token : Token;
    };
    type GetCallerIdentifierResult = {
        #Ok: GetCallerIdentifierSuccess;
        #Err: GetCallerIdentifierErr;
    };
    type GetCallerIdentifierSuccess = {
        accountIdentifier: AccountIdentifier;
    };
    type GetCallerIdentifierErr = {
        message: ?Text; 
        kind: {
            #InvalidToken;
        };
    };
    public shared query ({caller}) func get_caller_identifier (args: GetCallerIdentifierArgs) : async GetCallerIdentifierResult {
        let token = args.token;
        switch(token.symbol){
            case("ICP"){
                let subaccount = ICP.getDefaultAccount({caller});
                let hexEncoded = Hex.encode(
                    Blob.toArray(subaccount)
                );
                let result: AccountIdentifier = #text(hexEncoded);
                #Ok({accountIdentifier = result});
            };
            case(_){
                #Err({
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
