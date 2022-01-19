import A "./Account";
import T "./Types";
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
import Float "mo:base/Float";
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
import TimeBase "mo:base/Time";

actor Invoice {
// #region Types
    type Details = T.Details;
    type Token = T.Token;
    type TokenVerbose = T.TokenVerbose;
    type AccountIdentifier = T.AccountIdentifier;
    type Time = TimeBase.Time;
    
    type Invoice = {
        id: Nat;
        creator: Principal;
        details: ?Details;
        amount: Nat;
        amountPaid: Nat;
        token: TokenVerbose;
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
                    expiration = TimeBase.now() + (1000 * 60 * 60 * 24 * 7);
                    destination;
                    refundAccount = args.refundAccount;
                };
                
                invoices.put(id, invoice);

                #Ok({invoice});
            };
        };
    };
    type GenerateInvoiceIdArgs = {
        caller: Principal;
        id: Nat;
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

    // Generate an invoice ID using hashed values from the invoice arguments
    func generateInvoiceId (args: GenerateInvoiceIdArgs) : Blob {
        let idHash = SHA224.Digest();
        // Length of domain separator
        idHash.write([0x0A]);
        // Domain separator
        idHash.write(Blob.toArray(Text.encodeUtf8("invoice-id")));
        // Counter as Nonce
        idHash.write([Nat8.fromNat(args.id)]);
        // Principal of caller
        idHash.write(Blob.toArray(Principal.toBlob(args.caller)));

        let hashSum = idHash.sum();
        let crc32Bytes = A.beBytes(CRC32.ofArray(hashSum));
        let buf = Buffer.Buffer<Nat8>(32);
        let blob = Blob.fromArray(Array.append(crc32Bytes, hashSum));

        return blob;
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

                let subaccount: ICP.SubAccount = generateInvoiceId({ caller = args.caller; id = args.invoiceId });

                let accountArgs: ICP.SubAccountArgs = {
                    principal = canisterId;
                    subaccount = subaccount;
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
                let defaultSubaccount = Hex.encode(Blob.toArray(ICP.getDefaultSubaccount({caller})));
                let balance = await ICP.balance({account = defaultSubaccount});
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
    type VerifyInvoiceArgs = {
        id: Nat;
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
            #TransferError;
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
                let balanceResult = await ICP.balance({account = destination});

                 switch(balanceResult){
                    case(#Err err){
                        #Err({
                            message = ?"Could not get balance";
                            kind = #NotFound;
                        });
                    };
                    case(#Ok b){
                        let balance = b.balance;
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

                        // TODO Transfer funds to default subaccount of invoice creator
                        let subaccount: ICP.SubAccount = generateInvoiceId({ caller = i.creator; id = i.id });

                        let transferResult = await ICP.transfer({
                            memo = 0;
                            fee = {
                                e8s = 10000;
                            };
                            amount = {
                                // Total amount, minus the fee
                                e8s = Nat64.sub(Nat64.fromNat(i.amount), 10000);
                            };
                            from_subaccount = ?subaccount;
                            to = ICP.getDefaultSubaccount({caller});
                            created_at_time = null;
                        });
                        switch (transferResult) {
                            case (#Ok result) {
                                // Finally, update invoice
                                invoices.put(args.id, verifiedInvoice);
                                return #Ok(#Paid{
                                    invoice = verifiedInvoice;
                                });
                            };
                            case (#Err err) {
                                switch (err){
                                    case (#BadFee f){
                                        return #Err({
                                            message = ?"Bad fee";
                                            kind = #TransferError;
                                        });
                                    };
                                    case (#InsufficientFunds f){
                                        return #Err({
                                            message = ?"Insufficient funds";
                                            kind = #TransferError;
                                        });
                                    };
                                    case (_){
                                        return #Err({
                                            message = ?"Could not transfer funds to invoice creator.";
                                            kind = #TransferError;
                                        });
                                    }
                                };
                            };
                        };
 

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
        amount: Float;
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

    public shared ({caller}) func transfer (args: TransferArgs) : async () {
        let token = args.token;
        switch(token.symbol){
            case("ICP"){
                let now = Nat64.fromIntWrap(TimeBase.now());
                let destination : ICP.AccountIdentifier =  await accountIdentifierToBlob(args.destination);

                let icpTransferArgs = {
                    memo : ICP.Memo = 0;
                    amount: ICP.Tokens = {
                        // e8s are 10^-8 of a token
                        e8s = Nat64.fromIntWrap(Float.toInt(args.amount * 100000000));
                    };
                    created_at_time: ?ICP.TimeStamp = ?{
                        timestamp_nanos = now;
                    };
                    from_subaccount = ?Principal.toBlob(caller);
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
    public func accountIdentifierToBlob (identifier: AccountIdentifier) : async Blob {
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
        invoices := HashMap.fromIter(Iter.fromArray(entries), 16, Nat.equal, Hash.hash);
        entries := [];
    };
// #endregion
}
