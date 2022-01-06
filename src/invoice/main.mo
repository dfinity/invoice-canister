// import Ledger    "canister:ledger";

import A "./Account";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import ICP "./ICPLedger";
import Int "mo:base/Int";
import List "mo:base/List";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import T "./Types";
import Text "mo:base/List";
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
    var subaccounts : HashMap.HashMap<Principal, AccountIdentifier> = HashMap.fromIter();


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

    public func get_balance () {
        // TODO
    };

    public func transfer (args: TransferArgs) {
        let token = args.token;
        switch(token.symbol){
            case("ICP"){
                let now = Nat64.fromIntWrap(TimeBase.now());
                let icpTransferArgs = {
                    memo = 0;
                    amount = args.amount;
                    created_at_time: ICP.TimeStamp = {
                        timestamp_nanos = now;
                    };
                    fee = 10000;
                };
                ICP.transfer(icpTransferArgs);
                Debug.print("icp");
            };
            case(_){
                Debug.print("oops");
            };
        };
        // TODO
    };

    public func validate_payment () {
        // TODO
    };


}
