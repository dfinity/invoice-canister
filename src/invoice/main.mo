import A "./Account";
import T "./Types";
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
import List "mo:base/List";
import Nat "mo:base/Int64";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import TimeBase "mo:base/Time";
import Cycles "mo:base/ExperimentalCycles";

actor Invoice {
    let DOMAIN_SEPARATOR = "invoice";
    let DOMAIN_SEPARATOR2 = Text.concat("invoice_subaccount", "18");

    type Details = T.Details;
    type Token = T.Token;
    type AccountIdentifier = T.AccountIdentifier;
    type Time = TimeBase.Time;
    
    type Invoice = {
        id: Blob;
        creator: Principal;
        details: ?Details;
        amount: Nat;
        token: Token;
        verifiedAtTime: ?Time;
        paid: Bool;
        refunded: Bool;
        expiration: Time;
        destination: AccountIdentifier;
        refundAccount: ?AccountIdentifier;
    };

    // Get Balance
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
            #InvalidToken
        };
    };

    // Get DefaultAccount
    type GetAccountArgs = {
	    token: Token;
    };
    type GetAccountResult = {
        #Ok: GetAccountSuccess;
        #Err: GetAccountErr;
    };
    type GetAccountSuccess = {
        account: ?Text;
    };
    type GetAccountErr = {
        message: ?Text; 
        kind: {
            #InvalidToken
        };
    };

    // Create Invoice
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

    // Transfer
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

    /**
     * Application State
     */
    // var subaccounts : HashMap.HashMap<Principal, AccountIdentifier> = HashMap.fromIter();
    stable var invoiceCounter : Nat = 0;


    /**
     * Application Interface
     */    
    type Resp = {
        principal: Principal;
    };
    public shared ({caller}) func create_invoice (args: CreateInvoiceArgs) : async Principal {
        let idHash = SHA224.Digest();
        idHash.write([0x0A]);
        idHash.write(Blob.toArray(Text.encodeUtf8("invoice-id")));
        idHash.write([Nat8.fromNat(invoiceCounter)]);
        
        invoiceCounter += 1;
        
        idHash.write(Blob.toArray(Principal.toBlob(caller)));
        let hashSum = idHash.sum();
        let crc32Bytes = A.beBytes(CRC32.ofArray(hashSum));
        let blob = Blob.fromArray(Array.append(crc32Bytes, hashSum));

        Prim.principalOfBlob(blob);

        /* format of Invoice ID:
            byte for length of DS - domain separater - nonce - caller - details
        */ 
        // per-invoice subaccount generated from invoice id

        
        // default (final destination) subaccount for caller, controlled by current canister
        // Subaccount option - domain separator + principal of caller



        // let invoice : Invoice = {
        //     id;
        //     creator = caller;
        //     details = args.details;
        //     amount = args.amount;
        //     token = args.token;
        //     verifiedAtTime = null;
        //     paid = false;
        //     refunded = false;
        //     // 1 week in nanoseconds
        //     expiration = TimeBase.now() + (1000 * 60 * 60 * 24 * 7);
        //     destination = destination;
        //     refundAccount = args.refundAccount;
        // };
    };

    public func refund_invoice () {
        // TODO
    };

    public func get_invoice () {
        // TODO
    };

    public shared ({caller}) func get_balance (args: GetBalanceArgs) : async GetBalanceResult {
        let token = args.token;
        switch(token.symbol){
            case("ICP"){
                #Ok({
                    balance = await ICP.canisterBalance({caller})
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

    public shared ({caller}) func get_default_account (args: GetAccountArgs) : async GetAccountResult {
        let token = args.token;
        switch(token.symbol){
            case("ICP"){
                #Ok({
                    account = Text.decodeUtf8(ICP.getICPSubaccount({caller}))
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
                    from_subaccount : ?ICP.SubAccount = ?getICPSubaccount({caller});
                    to : ICP.AccountIdentifier = destination;
                    fee : ICP.Tokens = {
                        e8s = 10000;
                    };
                };
                let foo = await ICP.transfer(icpTransferArgs);
            };
            case(_){
                let bar = Debug.print("oops");
            };
        };
        ();
        // TODO - future tokens
    };


    func accountIdentifierToBlob (identifier: AccountIdentifier) : Blob {
        switch identifier {
            case(#text(identifier)){
                return Text.encodeUtf8(identifier);
            };
            case(#principal(identifier)){
                return Principal.toBlob(identifier);
            };
            case(#blob(identifier)){
                return identifier;
            };
        };
    };

    type icpSubaccountArgs = {
        caller: Principal;
    };
    func getICPSubaccount (args: icpSubaccountArgs) : ICP.SubAccount {
        ICP.getICPSubaccount(args);
    };
    type hashIdArgs = {
        caller: Principal;
    };

    public query func remaining_cycles() : async Nat {
        return Cycles.balance()
    };
}
