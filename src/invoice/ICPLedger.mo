// import Ledger "canister:ledger"

module {
    type Memo = Nat64;

    type Tokens = {
        e8s : Nat64;
    };

    public type TimeStamp = {
        timestamp_nanos: Nat64;
    };

    type AccountIdentifier = Blob;
    
    type SubAccount = Blob;

    type BlockIndex = Nat64;

    type TransferError = {
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

    public func transfer (args: TransferArgs) : TransferResult {
        #Ok(1);
    };
}
