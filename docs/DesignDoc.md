
# Payments - Invoice Canister

As we look to refine the developer experience around payments, we concluded that in some instances the ledger canister interface may be too “low level”. For example, a canister that would like to access/implement a payment system would need to implement from scratch things like protection against double spending against the ledger interface. For that reason, we propose to design an interface that will make it easier for a typical canister to add payment functionality.

## Goals

Goals for this project are as follows:
1. Solution should be simple to include and develop against locally
2. Canister can easily check its balance
3. Canister can verify that a payment has been satisfied
4. User can submit payment from a wallet
5. Design should be compatible with BTC, ETH, and SNS ledgers as they become available
  

## Non-goals

* We do not intend to change the ICP ledger
* This interface won't specifically handle minting cycles or other secondary ledger features
* Handling escrow payments
* Automating recurring payments

## Open Questions

* Should this be a new canister type in `dfx`, a single centralized canister on the NNS subnet, or both?

## The Interface
```
// interface.did
type Token = variant {
	ICP: Text;
	// More to come
};

type AccountIdentifier = variant { 
	Text;
	Principal;
},

type PrivateInfo = {
	// human-readable description of the transaction
	description: Text;
	meta: Blob;
};

type Invoice = record {
	id: Hash; // uuid
	creator: Principal;
	privateInfo: PrivateInfo;
	amount: Nat;
	amount_transferred: Nat;
	token: Token;
	verifiedAtTime: opt Time;
	paid: Bool;
	refunded: Bool;
	expiration: Time;
	destination: AccountIdentifier;
	refundAccount: opt AccountIdentifier;
};

type InvoiceCreateArgs = record {
	amount: Nat;
    token: Token;
	destination: opt AccountIdentifier;
	privateInfo: opt PrivateInfo;
	refundAccount: opt AccountIdentifier;
};

type TransferArgs = record {
    amount: Nat;
    token: Token;
	destination: AccountIdentifier;
	source: opt AccountIdentifier;
};

type BalanceArgs = record {
	token: Token;
};

service {
	create_invoice(InvoiceCreateArgs) -> (Invoice);
	refund_invoice(Hash) -> (Result);
	get_invoice(Hash) -> (Invoice) query;
	get_balance(BalanceArgs) -> Nat;
	transfer(TransferArgs) -> (Result);
	validate_payment(Hash) -> Status;
};
```


## Design Choices

The goal here was to design a flow where a client application such as a webpage, could initiate a payment flow that could be used to gate services or transfer ownership of assets.

The Invoice Canister will consolidate payments into a single balance per token, which will be the location that you can then transfer from and check your balance. The implementation may differ slightly for Bitcoin versus ICP, but the Invoice Canister will handle the implementation and abstract those differences into a single API.

### Basic Payment Flow ( hypothetical )

A canister smart contract can receive a request to purchase, create an invoice, and store the Principal of the caller and the UUID of the invoice.

Once the payment has been satisfied, the canister can check the status of the payment with `validate_payment`, while the Invoice canister checks the ledger. The canister can then present the status to the client, and satisfy the payment flow.
