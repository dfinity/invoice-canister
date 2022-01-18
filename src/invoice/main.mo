import A "./Account";
import T "./Types";
import Hex "./Hex";
import CRC32     "./CRC32";
import SHA256 "./SHA256";
import SHA224    "./SHA224";
import Prim "mo:⛔";

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import ICP "./ICPLedger";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import TimeBase "mo:base/Time";
import Cycles "mo:base/ExperimentalCycles";

actor Invoice {
// #region Types
    type Details = T.Details;
    type Token = T.Token;
    type AccountIdentifier = T.AccountIdentifier;
    type Time = TimeBase.Time;
    
    type Invoice = {
        id: Principal;
        creator: Principal;
        details: ?Details;
        amount: Nat;
        amountPaid: Nat;
        token: Token;
        verifiedAtTime: ?Time;
        paid: Bool;
        refunded: Bool;
        expiration: Time;
        destination: AccountIdentifier;
        refundAccount: ?AccountIdentifier;
    };
// #endregion

/**
* Application State
*/

// #region State

    stable var invoiceCounter : Nat = 0;
    stable var entries : [(Principal, Invoice)] = [];
    var invoices: HashMap.HashMap<Principal, Invoice> = HashMap.HashMap(16, Principal.equal, Principal.hash);
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
        let id : Principal = generateInvoiceId({caller});

        let destinationResult : GetDestinationAccountIdentifierResult = getDestinationAccountIdentifier({ token=args.token; invoiceId=id; caller });

        switch(destinationResult){
            case (#Err result) {
                return #Err({
                    message = ?"Invalid destination account identifier";
                    kind = #InvalidDestination;
                });
            };
            case (#Ok result) {
                let destination : AccountIdentifier = result.accountIdentifier;

                let invoice : Invoice = {
                    id;
                    creator = caller;
                    details = args.details;
                    amount = args.amount;
                    amountPaid = 0;
                    token = args.token;
                    verifiedAtTime = null;
                    paid = false;
                    refunded = false;
                    // 1 week in nanoseconds
                    expiration = TimeBase.now() + (1000 * 60 * 60 * 24 * 7);
                    destination = destination;
                    refundAccount = args.refundAccount;
                };
                
                invoices.put(id, invoice);

                #Ok({invoice});
            };
        };
    };
    type GenerateInvoiceIdArgs = {
        caller: Principal;
    };

    // Generate an invoice ID using hashed values from the invoice arguments
    func generateInvoiceId (args: GenerateInvoiceIdArgs) : Principal {
        let idHash = SHA224.Digest();
        // Length of domain separator
        idHash.write([0x0A]);
        // Domain separator
        idHash.write(Blob.toArray(Text.encodeUtf8("invoice-id")));
        // Counter as Nonce
        idHash.write([Nat8.fromNat(invoiceCounter)]);
        // Principal of caller
        idHash.write(Blob.toArray(Principal.toBlob(args.caller)));
        
        // increment counter
        invoiceCounter += 1;

        let hashSum = idHash.sum();
        let blob = Blob.fromArray(hashSum);

        // TODO - replace with Principal.fromBlob once available
        return Prim.principalOfBlob(blob);
    };

    // #region Get Destination Account Identifier
    type GetDestinationAccountIdentifierArgs = {
        token : Token;
        caller : Principal;
        invoiceId : Principal;
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
                let accountArgs: ICP.SubAccountArgs = {
                    principal=args.caller;
                    subaccount=Principal.toBlob(args.invoiceId);
                };
                let account = ICP.getICPSubaccount(accountArgs);
                let hexEncoded = Hex.encode(
                    Blob.toArray(account)
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
// #endregion

// #region Get Invoice
    type GetInvoiceArgs = {
        id: Principal;
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
                let defaultSubaccount = Hex.encode(Blob.toArray(ICP.getDefaultSubaccount({caller})));
                #Ok({
                    balance = await ICP.balance({account = defaultSubaccount})
                });
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
    type VerifyInvoiceArgs = {
        id: Principal;
    };
    type VerifyInvoiceResult = {
        #Ok: VerifyInvoiceSuccess;
        #Err: VerifyInvoiceErr;
    };
    type VerifyInvoiceSuccess = {
        #Paid: {
            invoice: Invoice;
        };
        #AlreadyVerified: {
            invoice: Invoice;
        };
    };
    type VerifyInvoiceErr = {
        message: ?Text; 
        kind: {
            #InvalidInvoiceId;
            #NotFound;
            #NotYetPaid;
            #Expired;
        };
    };
    public shared ({caller}) func verify_invoice (args: VerifyInvoiceArgs) : async VerifyInvoiceResult {
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

                // TODO - implement for multiple tokens
                let destination = accountIdentifierToText(i.destination);
                let balance = await ICP.balance({account = destination});

                // If balance is less than invoice amount, return error
                if(balance < i.amount){

                    if(balance != i.amountPaid){
                        let updatedInvoice = {
                            id = i.id;
                            creator = caller;
                            details = i.details;
                            amount = i.amount;
                            // Update invoice with latest balance
                            amountPaid = balance;
                            token = i.token;
                            verifiedAtTime = i.verifiedAtTime;
                            paid = false;
                            refunded = false;
                            expiration = i.expiration;
                            destination = i.destination;
                            refundAccount = i.refundAccount;
                        };
                        let replaced = invoices.replace(i.id, updatedInvoice);
                    };

                    return #Err({
                        message = ?Text.concat("Insufficient balance. Current Balance is ", Nat.toText(balance));
                        kind = #NotYetPaid;
                    });
                };

                let verifiedAtTime: ?Time = ?TimeBase.now();
                // Otherwise, update with latest balance and mark as paid
                let verifiedInvoice = {
                    id = i.id;
                    creator = caller;
                    details = i.details;
                    amount = i.amount;
                    // update amountPaid
                    amountPaid = balance;
                    token = i.token;
                    // update verifiedAtTime
                    verifiedAtTime;
                    // update paid
                    paid = true;
                    refunded = false;
                    expiration = i.expiration;
                    destination = i.destination;
                    refundAccount = i.refundAccount;
                };
                invoices.put(args.id, verifiedInvoice);

                // TODO Transfer funds to default subaccount of invoice creator

                return #Ok(#Paid{invoice = verifiedInvoice});
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
        source: ?AccountIdentifier;
    };
    type TransferResult = {
        #Ok: TransferSuccess;
        #Err: TransferError;
    };
    type TransferSuccess = {
        blockHeight: Nat;
    };
    type TransferError = {
        #InsufficientFunds: {
            balance: Nat;
        };
        #GenericException: {
            message: Text;
        };
    };

    public shared ({caller}) func transfer (args: TransferArgs) : () {
        let token = args.token;
        switch(token.symbol){
            case("ICP"){
                let now = Nat64.fromIntWrap(TimeBase.now());
                let amount = Nat64.fromNat(args.amount);
                let destination : ICP.AccountIdentifier = accountIdentifierToBlob(args.destination);

                let icpTransferArgs = {
                    memo : ICP.Memo = 0;
                    amount: ICP.Tokens = {
                        e8s = amount;
                    };
                    created_at_time: ?ICP.TimeStamp = ?{
                        timestamp_nanos = now;
                    };
                    from_subaccount : ?ICP.SubAccount = ?ICP.getDefaultSubaccount({caller});
                    to : ICP.AccountIdentifier = destination;
                    fee : ICP.Tokens = {
                        e8s = 10000;
                    };
                };
                let result = await ICP.transfer(icpTransferArgs);
            };
            case(_){
            };
        };
        ();
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
                let subaccount = ICP.getDefaultSubaccount({caller});
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
    func accountIdentifierToBlob (identifier: AccountIdentifier) : Blob {
        switch identifier {
            case(#text(identifier)){
                switch (Hex.decode(identifier)) {
                    case(#ok v){
                        return Blob.fromArray(v);
                    };
                    case(#err _){
                        return "";
                    };
                };
            };
            case(#principal(identifier)){
                return Principal.toBlob(identifier);
            };
            case(#blob(identifier)){
                return identifier;
            };
        };
    };
    func accountIdentifierToText (identifier: AccountIdentifier) : Text {
        switch identifier {
            case(#text(identifier)){
                return identifier;
            };
            case(#principal(identifier)){
                return Principal.toText(identifier);
            };
            case(#blob(identifier)){
                return Hex.encode(Blob.toArray(identifier));
            };
        };
    };


    public query func remaining_cycles() : async Nat {
        return Cycles.balance()
    };
// #endregion

// #region Upgrade Hooks
    system func preupgrade() {
        entries := Iter.toArray(invoices.entries());
    };

    system func postupgrade() {
        invoices := HashMap.fromIter(Iter.fromArray(entries), 16, Principal.equal, Principal.hash);
        entries := [];
    };
// #endregion
}
