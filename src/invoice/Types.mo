import Time "mo:base/Time";

module {

/**
* Base Types
*/
// #region Base Types
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
    refundedAtTime: ?Time.Time;
    paid: Bool;
    refunded: Bool;
    expiration: Time.Time;
    destination: AccountIdentifier;
    refundAccount: ?AccountIdentifier;
  };
// #endregion

/**
* Service Args and Result Types
*/  

// #region create_invoice
  public type CreateInvoiceArgs = {
    amount: Nat;
    token: Token;
    details: ?Details;
  };
  public type CreateInvoiceResult = {
    #Ok: CreateInvoiceSuccess;
    #Err: CreateInvoiceErr;
  };
  public type CreateInvoiceSuccess = {
    invoice: Invoice;
  };
  public type CreateInvoiceErr = {
    message: ?Text; 
    kind: {
      #InvalidToken;
      #InvalidAmount;
      #InvalidDestination;
      #InvalidDetails;
    };
  };
// #endregion

// #region Get Destination Account Identifier
  public type GetDestinationAccountIdentifierArgs = {
    token : Token;
    caller : Principal;
    invoiceId : Nat;
  };
  public type GetDestinationAccountIdentifierResult = {
    #Ok: GetDestinationAccountIdentifierSuccess;
    #Err: GetDestinationAccountIdentifierErr;
  };
  public type GetDestinationAccountIdentifierSuccess = {
    accountIdentifier: AccountIdentifier;
  };
  public type GetDestinationAccountIdentifierErr = {
    message: ?Text; 
    kind: {
        #InvalidToken;
        #InvalidInvoiceId;
    };
  };
// #endregion

// #region get_invoice
  public type GetInvoiceArgs = {
    id: Nat;
  };
  public type GetInvoiceResult = {
    #Ok: GetInvoiceSuccess;
    #Err: GetInvoiceErr;
  };
  public type GetInvoiceSuccess = {
    invoice: Invoice;
  };
  public type GetInvoiceErr = {
    message: ?Text; 
    kind: {
      #InvalidInvoiceId;
      #NotFound;
    };
  };
// #endregion

// #region get_balance
  public type GetBalanceArgs = {
    token: Token;
  };
  public type GetBalanceResult = {
    #Ok: GetBalanceSuccess;
    #Err: GetBalanceErr;
  };
  public type GetBalanceSuccess = {
    balance: Nat;
  };
  public type GetBalanceErr = {
    message: ?Text; 
    kind: {
      #InvalidToken;
      #NotFound;
    };
  };
// #endregion

// #region verify_invoice
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
// #endregion

// #region transfer
  public type TransferArgs = {
    amount: Nat;
    token: Token;
    destination: AccountIdentifier;
  };
  public type TransferResult = {
    #Ok: TransferSuccess;
    #Err: TransferError;
  };
  public type TransferSuccess = {
    blockHeight: Nat64;
  };
  public type TransferError = {
    message: ?Text; 
    kind: {
      #BadFee;
      #InsufficientFunds;
      #InvalidToken;
      #InvalidDestination;
      #Other;
    };
  };
// #endregion

// #region get_caller_identifier
  public type GetCallerIdentifierArgs = {
    token : Token;
  };
  public type GetCallerIdentifierResult = {
    #Ok: GetCallerIdentifierSuccess;
    #Err: GetCallerIdentifierErr;
  };
  public type GetCallerIdentifierSuccess = {
    accountIdentifier: AccountIdentifier;
  };
  public type GetCallerIdentifierErr = {
    message: ?Text; 
    kind: {
      #InvalidToken;
    };
  };
// #endregion

// #region refund_invoice
  public type RefundInvoiceArgs = {
    id: Nat;
    refundAccount: AccountIdentifier;
    amount: Nat;
  };
  public type RefundInvoiceResult = {
    #Ok: RefundInvoiceSuccess;
    #Err: RefundInvoiceErr;
  };
  public type RefundInvoiceSuccess = {
    blockHeight: Nat64;
  };
  public type RefundInvoiceErr = {
    message: ?Text; 
    kind: {
      #InvalidInvoiceId;
      #NotFound;
      #NotYetPaid;
      #InvalidDestination;
      #TransferError;
      #InsufficientFunds;
      #InvalidToken;
      #AlreadyRefunded;
      #BadFee;
      #Other;
    };
  };
// #endregion
};
