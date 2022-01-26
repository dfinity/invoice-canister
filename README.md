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

## Testing

To test, you will need to install `moc` from the latest `motoko-<system>-<version>.tar.gz` release. https://github.com/dfinity/motoko/releases.

Then, install Vessel following the guide at https://github.com/dfinity/vessel.

You will also need to install `wasmtime`. For macOS, you can install with `brew install wasmtime`. For Linux, you can install with `sudo apt-get install wasmtime`.

To run unit tests, use `make unit-test`.
To run end-to-end tests, use `make e2e-test`.
