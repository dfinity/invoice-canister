import Time "mo:base/Time";

module {
    public type Token = {
        symbol: Text;
    };
    public type TokenVerbose = {
        symbol: Text;
        decimals: Int;
        meta: ?{
            Issuer: Text;
        };
    };
    public type AccountIdentifier = {
        #text: Text;
        #principal: Principal;
        #blob: Blob;
    };
    public type Details = {
        description: Text;
        meta: Blob;
    };
    public type Invoice = {
        id: Nat;
        creator: Principal;
        details: ?Details;
        amount: Nat;
        amountPaid: Nat;
        token: TokenVerbose;
        verifiedAtTime: ?Time.Time;
        paid: Bool;
        refunded: Bool;
        expiration: Time.Time;
        destination: AccountIdentifier;
        refundAccount: ?AccountIdentifier;
    };

    // Verify Invoice
    public type VerifyInvoiceArgs = {
        id: Nat;
    };
    public type VerifyInvoiceResult = {
        #Ok: VerifyInvoiceSuccess;
        #Err: VerifyInvoiceErr;
    };
    public type VerifyInvoiceSuccess = {
        #Paid: {
            invoice: Invoice;
        };
        #AlreadyVerified: {
            invoice: Invoice;
        };
    };
    type VerifyInvoiceErr = {
        message: ?Text; 
        kind: {
            #InvalidInvoiceId;
            #NotFound;
            #NotYetPaid;
            #Expired;
            #TransferError;
            #InvalidToken;
        };
    };
};
