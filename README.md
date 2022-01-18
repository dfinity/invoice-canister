# Invoice Canister

This project will provide an example and simplified experience for accepting payments in smart contracts.

## Integrating with the Invoice Canister
Include this code in your `dfx.json` and follow our `self-hosted` example: TODO

## Getting Started - Development
Make sure you have followed the DFX installation instructions from https://smartcontracts.org.

Start up your local environment with `dfx start`.
In another terminal, run `dfx deploy`
You can then interact with the canister with `dfx canister call invoice ...`, or interact with one of our examples under `/examples/` TODO - add examples

## Sample invoice format

To create an invoice, run something along the lines of 

```
dfx canister call invoice create_invoice '(record { token = record { symbol="ICP" }; amount = 10_000_000_000 })'
```

Get Invoice

```
dfx canister call invoice get_invoice '(record { id = 1 })'
```
