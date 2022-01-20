import Ledger "canister:ledger";
import A "./Account";
import T "./Types";
import U "./Utils";
import SelfMeta "./SelfMeta";
import SHA224 "./SHA224";
import CRC32     "./CRC32";
import Hex "./Hex";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Text "mo:base/Text";

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

    public type ICPVerifyInvoiceArgs = {
        invoice : T.Invoice;
        caller : Principal;
    };
    public func verifyInvoice(args: ICPVerifyInvoiceArgs) : async T.VerifyInvoiceResult {
        let i = args.invoice;
        let destination = U.accountIdentifierToText(i.destination);
        let balanceResult = await balance({account = destination});

        switch(balanceResult){
            case(#Err err){
                #Err({
                    message = ?"Could not get balance";
                    kind = #NotFound;
                });
            };
            case(#Ok b){
                let balance = b.balance;
                // If balance is less than invoice amount, return error
                if(balance < i.amount){

                    if(balance != i.amountPaid){
                        let updatedInvoice = {
                            id = i.id;
                            creator = args.caller;
                            details = i.details;
                            amount = i.amount;
                            // Update invoice with latest balance
                            amountPaid = balance;
                            token = i.token;
                            verifiedAtTime = i.verifiedAtTime;
                            paid = false;
                            refunded = false;
                            expiration = i.expiration;
                            destination = i.destination;
                            refundAccount = i.refundAccount;
                        };
                    };

                    return #Err({
                        message = ?Text.concat("Insufficient balance. Current Balance is ", Nat.toText(balance));
                        kind = #NotYetPaid;
                    });
                };

                let verifiedAtTime: ?Time.Time = ?Time.now();
                // Otherwise, update with latest balance and mark as paid
                let verifiedInvoice = {
                    id = i.id;
                    creator = args.caller;
                    details = i.details;
                    amount = i.amount;
                    // update amountPaid
                    amountPaid = balance;
                    token = i.token;
                    // update verifiedAtTime
                    verifiedAtTime;
                    // update paid
                    paid = true;
                    refunded = false;
                    expiration = i.expiration;
                    destination = i.destination;
                    refundAccount = i.refundAccount;
                };

                // TODO Transfer funds to default subaccount of invoice creator
                let subaccount: SubAccount = U.generateInvoiceId({ caller = i.creator; id = i.id });

                let transferResult = await transfer({
                    memo = 0;
                    fee = {
                        e8s = 10000;
                    };
                    amount = {
                        // Total amount, minus the fee
                        e8s = Nat64.sub(Nat64.fromNat(i.amount), 10000);
                    };
                    from_subaccount = ?subaccount;
                    to = getDefaultAccount({caller = args.caller});
                    created_at_time = null;
                });
                switch (transferResult) {
                    case (#Ok result) {
                        return #Ok(#Paid{
                            invoice = verifiedInvoice;
                        });
                    };
                    case (#Err err) {
                        switch (err){
                            case (#BadFee f){
                                return #Err({
                                    message = ?"Bad fee";
                                    kind = #TransferError;
                                });
                            };
                            case (#InsufficientFunds f){
                                return #Err({
                                    message = ?"Insufficient funds";
                                    kind = #TransferError;
                                });
                            };
                            case (_){
                                return #Err({
                                    message = ?"Could not transfer funds to invoice creator.";
                                    kind = #TransferError;
                                });
                            }
                        };
                    };
                };


            };
        };
    };
}
