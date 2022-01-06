import Ledger "canister:ledger";
import A "./Account";

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
    public func canisterBalance(args: AccountArgs) : async Ledger.Token {
        let defaultAccount =  {
            account = A.accountIdentifier(args.caller, A.defaultSubaccount());
        };
        await Ledger.account_balance(defaultAccount);
    };

    public func getICPSubaccount(args: AccountArgs) : Blob {
        A.accountIdentifier(args.caller, A.defaultSubaccount());
    };
}
