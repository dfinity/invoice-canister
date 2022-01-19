import Ledger "canister:ledger";
import A "./Account";
import SelfMeta "./SelfMeta";
import Hex "./Hex";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";

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
        let result = await Ledger.transfer({
            memo = args.memo;
            amount = args.amount;
            fee = args.fee;
            from_subaccount = args.from_subaccount;
            to = args.to;
            created_at_time = args.created_at_time;
        });
        switch (result){
            case (#Ok index){
                Debug.print(Nat64.toText(index));
            };
            case (#Err _){
                Debug.print("Error");
            };
        };
        return result;
    };

    type AccountArgs = {
        // Hex-encoded AccountIdentifier
        account : Text;
    };
    type BalanceResult = {
        #Ok: {
            balance: Nat;
        };
        #Err: {
            error: Text;
        };
    };
    public func balance(args: AccountArgs) : async BalanceResult {
        let meta : SelfMeta.Meta = SelfMeta.getMeta();
        switch (Hex.decode(args.account)){
            case (#err err){
                #Err({
                    error = "Invalid account";
                });
            };
            case (#ok account) {
                let balance = await Ledger.account_balance({account = Blob.fromArray(account)});
                #Ok({
                    balance = Nat64.toNat(balance.e8s);
                });
            };
        };
    };

    type DefaultSubaccountArgs = {
        // Hex-encoded AccountIdentifier
        caller : Principal;
    };
    public func getDefaultSubaccount(args: DefaultSubaccountArgs) : Blob {
        let meta : SelfMeta.Meta = SelfMeta.getMeta();
        let canisterId = meta.canisterId;
        A.accountIdentifier(canisterId, Principal.toBlob(args.caller));
    };

    public type SubAccountArgs = {
        principal : Principal;
        subaccount : SubAccount;
    };
    public func getICPSubaccount(args: SubAccountArgs) : Blob {
        A.accountIdentifier(args.principal, args.subaccount);
    };
}
