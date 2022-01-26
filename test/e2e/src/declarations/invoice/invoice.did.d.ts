import type { Principal } from '@dfinity/principal';
export type AccountIdentifier = { 'principal' : Principal } |
  { 'blob' : Array<number> } |
  { 'text' : string };
export type AccountIdentifier__1 = { 'principal' : Principal } |
  { 'blob' : Array<number> } |
  { 'text' : string };
export interface CreateInvoiceArgs {
  'token' : Token,
  'details' : [] | [Details],
  'amount' : bigint,
}
export interface CreateInvoiceErr {
  'kind' : { 'InvalidDetails' : null } |
    { 'InvalidAmount' : null } |
    { 'InvalidDestination' : null } |
    { 'InvalidToken' : null },
  'message' : [] | [string],
}
export type CreateInvoiceResult = { 'Ok' : CreateInvoiceSuccess } |
  { 'Err' : CreateInvoiceErr };
export interface CreateInvoiceSuccess { 'invoice' : Invoice }
export interface Details { 'meta' : Array<number>, 'description' : string }
export interface GetBalanceArgs { 'token' : Token }
export interface GetBalanceErr {
  'kind' : { 'NotFound' : null } |
    { 'InvalidToken' : null },
  'message' : [] | [string],
}
export type GetBalanceResult = { 'Ok' : GetBalanceSuccess } |
  { 'Err' : GetBalanceErr };
export interface GetBalanceSuccess { 'balance' : bigint }
export interface GetCallerIdentifierArgs { 'token' : Token }
export interface GetCallerIdentifierErr {
  'kind' : { 'InvalidToken' : null },
  'message' : [] | [string],
}
export type GetCallerIdentifierResult = { 'Ok' : GetCallerIdentifierSuccess } |
  { 'Err' : GetCallerIdentifierErr };
export interface GetCallerIdentifierSuccess {
  'accountIdentifier' : AccountIdentifier,
}
export interface GetInvoiceArgs { 'id' : bigint }
export interface GetInvoiceErr {
  'kind' : { 'NotFound' : null } |
    { 'InvalidInvoiceId' : null },
  'message' : [] | [string],
}
export type GetInvoiceResult = { 'Ok' : GetInvoiceSuccess } |
  { 'Err' : GetInvoiceErr };
export interface GetInvoiceSuccess { 'invoice' : Invoice }
export interface Invoice {
  'id' : bigint,
  'creator' : Principal,
  'destination' : AccountIdentifier,
  'token' : TokenVerbose,
  'refundedAtTime' : [] | [Time],
  'paid' : boolean,
  'refunded' : boolean,
  'verifiedAtTime' : [] | [Time],
  'amountPaid' : bigint,
  'expiration' : Time,
  'refundAccount' : [] | [AccountIdentifier],
  'details' : [] | [Details],
  'amount' : bigint,
}
export interface RefundInvoiceArgs {
  'id' : bigint,
  'refundAccount' : AccountIdentifier,
  'amount' : bigint,
}
export interface RefundInvoiceErr {
  'kind' : { 'TransferError' : null } |
    { 'NotFound' : null } |
    { 'InvalidToken' : null } |
    { 'InvalidInvoiceId' : null } |
    { 'AlreadyRefunded' : null } |
    { 'NotYetPaid' : null } |
    { 'NoRefundDestination' : null },
  'message' : [] | [string],
}
export type RefundInvoiceResult = { 'Ok' : RefundInvoiceSuccess } |
  { 'Err' : RefundInvoiceErr };
export interface RefundInvoiceSuccess { 'blockHeight' : bigint }
export type Time = bigint;
export interface Token { 'symbol' : string }
export interface TokenVerbose {
  'decimals' : bigint,
  'meta' : [] | [{ 'Issuer' : string }],
  'symbol' : string,
}
export interface TransferArgs {
  'destination' : AccountIdentifier,
  'token' : Token,
  'amount' : bigint,
}
export interface TransferError {
  'kind' : { 'BadFee' : null } |
    { 'InvalidToken' : null } |
    { 'Other' : null } |
    { 'InsufficientFunds' : null },
  'message' : [] | [string],
}
export type TransferResult = { 'Ok' : TransferSuccess } |
  { 'Err' : TransferError };
export interface TransferSuccess { 'blockHeight' : bigint }
export interface VerifyInvoiceArgs { 'id' : bigint }
export interface VerifyInvoiceErr {
  'kind' : { 'TransferError' : null } |
    { 'NotFound' : null } |
    { 'InvalidToken' : null } |
    { 'InvalidInvoiceId' : null } |
    { 'NotYetPaid' : null } |
    { 'Expired' : null },
  'message' : [] | [string],
}
export type VerifyInvoiceResult = { 'Ok' : VerifyInvoiceSuccess } |
  { 'Err' : VerifyInvoiceErr };
export type VerifyInvoiceSuccess = { 'Paid' : { 'invoice' : Invoice } } |
  { 'AlreadyVerified' : { 'invoice' : Invoice } };
export interface _SERVICE {
  'accountIdentifierToBlob' : (arg_0: AccountIdentifier__1) => Promise<
      Array<number>
    >,
  'create_invoice' : (arg_0: CreateInvoiceArgs) => Promise<CreateInvoiceResult>,
  'get_balance' : (arg_0: GetBalanceArgs) => Promise<GetBalanceResult>,
  'get_caller_identifier' : (arg_0: GetCallerIdentifierArgs) => Promise<
      GetCallerIdentifierResult
    >,
  'get_invoice' : (arg_0: GetInvoiceArgs) => Promise<GetInvoiceResult>,
  'refund_invoice' : (arg_0: RefundInvoiceArgs) => Promise<RefundInvoiceResult>,
  'remaining_cycles' : () => Promise<bigint>,
  'transfer' : (arg_0: TransferArgs) => Promise<TransferResult>,
  'verify_invoice' : (arg_0: VerifyInvoiceArgs) => Promise<VerifyInvoiceResult>,
}
