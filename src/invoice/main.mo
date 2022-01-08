// import Ledger    "canister:ledger";

import A "./Account";
import T "./Types";

import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import ICP "./ICPLedger";
import Int "mo:base/Int";
import List "mo:base/List";
import Nat "mo:base/Int64";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import TimeBase "mo:base/Time";

actor Invoice {

    type Details = T.Details;
    type Token = T.Token;
    type AccountIdentifier = T.AccountIdentifier;
    type Time = TimeBase.Time;
    
    type Invoice = {
        id: Hash.Hash;
        creator: Principal;
        details: Details;
        amount: Nat;
        token: Token;
        verifiedAtTime: ?Time;
        paid: Bool;
        refunded: Bool;
        expiration: Time;
        destination: AccountIdentifier;
        refundAccount: ?AccountIdentifier;
    };
    
    type InvoiceCreateArgs = {
        amount: Nat;
        token: Token;
        destination: ?AccountIdentifier;
        details: Details;
        refundAccount: ?AccountIdentifier;
    };

    // Get Balance
    type getBalanceArgs = {
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


    /**
     * Application Interface
     */    

    public func create_invoice () {
        // TODO
    };

    public func refund_invoice () {
        // TODO
    };

    public func get_invoice () {
        // TODO
    };

    public shared ({caller}) func get_balance (args: getBalanceArgs) : async GetBalanceResult {
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

    public func validate_payment () {
        // TODO
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

}
