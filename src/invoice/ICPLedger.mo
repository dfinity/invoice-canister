import Ledger "canister:ledger";
import A "./Account";
import SelfMeta "./SelfMeta";
import SHA224 "./SHA224";
import CRC32     "./CRC32";
import Hex "./Hex";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
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

    type DefaultAccountArgs = {
        // Hex-encoded AccountIdentifier
        caller : Principal;
    };
    public func getDefaultAccount(args: DefaultAccountArgs) : Blob {
        let meta : SelfMeta.Meta = SelfMeta.getMeta();
        let canisterId = meta.canisterId;
        A.accountIdentifier(canisterId, principalToSubaccount(args.caller));
    };

    public type GetICPAccountIdentifierArgs = {
        principal : Principal;
        subaccount : SubAccount;
    };
    public func getICPAccountIdentifier(args: GetICPAccountIdentifierArgs) : Blob {
        A.accountIdentifier(args.principal, args.subaccount);
    };

    public func principalToSubaccount(principal: Principal) : Blob {
        let idHash = SHA224.Digest();
        idHash.write(Blob.toArray(Principal.toBlob(principal)));
        let hashSum = idHash.sum();
        let crc32Bytes = A.beBytes(CRC32.ofArray(hashSum));
        let buf = Buffer.Buffer<Nat8>(32);
        let blob = Blob.fromArray(Array.append(crc32Bytes, hashSum));

        return blob;
    };
}
