import Time "mo:base/Time";
import Result "mo:base/Result";

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
  public type CreateInvoiceResult = Result.Result<CreateInvoiceSuccess, CreateInvoiceErr>;
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
      #Other;
    };
  };
// #endregion

// #region Get Destination Account Identifier
  public type GetDestinationAccountIdentifierArgs = {
    token : Token;
    caller : Principal;
    invoiceId : Nat;
  };
  public type GetDestinationAccountIdentifierResult = Result.Result<GetDestinationAccountIdentifierSuccess, GetDestinationAccountIdentifierErr>;
  public type GetDestinationAccountIdentifierSuccess = {
    accountIdentifier: AccountIdentifier;
  };
  public type GetDestinationAccountIdentifierErr = {
    message: ?Text; 
    kind: {
        #InvalidToken;
        #InvalidInvoiceId;
        #Other;
    };
  };
// #endregion

// #region get_invoice
  public type GetInvoiceArgs = {
    id: Nat;
  };
  public type GetInvoiceResult = Result.Result<GetInvoiceSuccess, GetInvoiceErr>;
  public type GetInvoiceSuccess = {
    invoice: Invoice;
  };
  public type GetInvoiceErr = {
    message: ?Text; 
    kind: {
      #InvalidInvoiceId;
      #NotFound;
      #Other;
    };
  };
// #endregion

// #region get_balance
  public type GetBalanceArgs = {
    token: Token;
  };
  public type GetBalanceResult = Result.Result<GetBalanceSuccess, GetBalanceErr>;
  public type GetBalanceSuccess = {
    balance: Nat;
  };
  public type GetBalanceErr = {
    message: ?Text; 
    kind: {
      #InvalidToken;
      #NotFound;
      #Other;
    };
  };
// #endregion

// #region verify_invoice
  public type VerifyInvoiceArgs = {
    id: Nat;
  };
  public type VerifyInvoiceResult = Result.Result<VerifyInvoiceSuccess, VerifyInvoiceErr>;
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
      #InvalidAccount;
      #Other;
    };
  };
// #endregion

// #region transfer
  public type TransferArgs = {
    amount: Nat;
    token: Token;
    destination: AccountIdentifier;
  };
  public type TransferResult = Result.Result<TransferSuccess, TransferError>;
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
  public type GetCallerIdentifierResult = Result.Result<GetCallerIdentifierSuccess, GetCallerIdentifierErr>;
  public type GetCallerIdentifierSuccess = {
    accountIdentifier: AccountIdentifier;
  };
  public type GetCallerIdentifierErr = {
    message: ?Text; 
    kind: {
      #InvalidToken;
      #Other;
    };
  };
// #endregion

// #region refund_invoice
  public type RefundInvoiceArgs = {
    id: Nat;
    refundAccount: AccountIdentifier;
    amount: Nat;
  };
  public type RefundInvoiceResult = Result.Result<RefundInvoiceSuccess, RefundInvoiceErr>;
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

// #region accountIdentifierToBlob
  public type AccountIdentifierToBlobArgs = {
    accountIdentifier: AccountIdentifier;
    canisterId: ?Principal;
  };
  public type AccountIdentifierToBlobResult = Result.Result<AccountIdentifierToBlobSuccess, AccountIdentifierToBlobErr>;
  public type AccountIdentifierToBlobSuccess = Blob;
  public type AccountIdentifierToBlobErr = {
    message: ?Text; 
    kind: {
      #InvalidAccountIdentifier;
      #Other;
    };
  };
// #endregion

// #region accountIdentifierToText
  public type AccountIdentifierToTextArgs = {
    accountIdentifier: AccountIdentifier;
    canisterId: ?Principal;
  };
  public type AccountIdentifierToTextResult = Result.Result<AccountIdentifierToTextSuccess, AccountIdentifierToTextErr>;
  public type AccountIdentifierToTextSuccess = Text;
  public type AccountIdentifierToTextErr = {
    message: ?Text; 
    kind: {
      #InvalidAccountIdentifier;
      #Other;
    };
  };
// #endregion
};
