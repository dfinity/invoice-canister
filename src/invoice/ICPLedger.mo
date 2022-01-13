import Ledger "canister:ledger";
import A "./Account";
import Nat64 "mo:base/Nat64";

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
        caller : Principal;
    };
    // Returns current balance on the default account of this canister.
    public func canisterBalance(args: AccountArgs) : async Nat {
        let defaultAccount =  {
            account = A.accountIdentifier(args.caller, A.defaultSubaccount());
        };
        let balance = await Ledger.account_balance(defaultAccount);
        return Nat64.toNat(balance.e8s);
    };

    public func getDefaultSubaccount(args: AccountArgs) : Blob {
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
