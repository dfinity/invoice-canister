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
        id: Principal;
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
                    token = args.token;
                    verifiedAtTime = null;
                    paid = false;
                    refunded = false;
                    // 1 week in nanoseconds
                    expiration = TimeBase.now() + (1000 * 60 * 60 * 24 * 7);
                    destination = destination;
                    refundAccount = args.refundAccount;
                };

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

   
    type hashIdArgs = {
        caller: Principal;
    };

    public query func remaining_cycles() : async Nat {
        return Cycles.balance()
    };
}
