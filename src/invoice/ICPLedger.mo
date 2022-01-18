import Ledger "canister:ledger";
import A "./Account";
import Hex "./Hex";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";

module {
    public type Memo = Nat64;

    public type Tokens = {
        e8s : Nat64;
    };

    public type TimeStamp = {
        timestamp_nanos: Nat64;
    };

    public type AccountIdentifier = Blob;
    
    public type SubAccount = Blob;

    public type BlockIndex = Nat64;

    public type TransferError = {
        #BadFee: {
            expected_fee: Tokens;
        };
        #InsufficientFunds: {
            balance: Tokens;
        };
        #TxTooOld: {
            allowed_window_nanos: Nat64;
        };
        #TxCreatedInFuture;
        #TxDuplicate : {
            duplicate_of: BlockIndex;
        };
    };

    public type TransferArgs = {
        memo: Memo;
        amount: Tokens;
        fee: Tokens;
        from_subaccount: ?SubAccount;
        to: AccountIdentifier;
        created_at_time: ?TimeStamp;
    };

    public type TransferResult = {
        #Ok: BlockIndex;
        #Err: TransferError;
    };

    public func transfer (args: TransferArgs) : async TransferResult {
        #Ok(1);
    };

    type AccountArgs = {
        // Hex-encoded AccountIdentifier
        account : Text;
    };
    public func balance(args: AccountArgs) : async Nat {
        switch (Hex.decode(args.account)){
            case (#err err){
                let balance : Nat = 0;
                return balance;
            };
            case (#ok account) {
                let balance = await Ledger.account_balance({account = Blob.fromArray(account)});
                return Nat64.toNat(balance.e8s);
            };
        };
    };

    type DefaultSubaccountArgs = {
        // Hex-encoded AccountIdentifier
        caller : Principal;
    };
    public func getDefaultSubaccount(args: DefaultSubaccountArgs) : Blob {
        A.accountIdentifier(args.caller, A.defaultSubaccount());
    };

    public type SubAccountArgs = {
        principal : Principal;
        subaccount : SubAccount;
    };
    public func getICPSubaccount(args: SubAccountArgs) : Blob {
        A.accountIdentifier(args.principal, args.subaccount);
    };
}
