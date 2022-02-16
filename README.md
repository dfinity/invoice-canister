# Invoice Canister

This project provides a simple interface for creating and paying invoices in various tokens on the Internet Computer. It is a custodial solution, intended to be a simple, drop-in payments solution for any canister. To read more about the design of the canister, see the [Design Doc](./docs/DesignDoc.md).

## Integrating with the Invoice Canister

Include this code in your `dfx.json` and follow our `self-hosted` example: TODO

## Getting Started - Development

Make sure you have followed the DFX installation instructions from https://smartcontracts.org.

Run the `install-local.sh` script to install the ICP ledger and and the invoice canister on your device. You can make calls using the `dfx` sdk, or you can see test cases running through the flows under the `test` directory.

## Testing

To test, you will need to install `moc` from the latest `motoko-<system>-<version>.tar.gz` release. https://github.com/dfinity/motoko/releases.

Then, install Vessel following the guide at https://github.com/dfinity/vessel.

You will also need to install `wasmtime`. For macOS, you can install with `brew install wasmtime`. For Linux, you can install with `sudo apt-get install wasmtime`.

To run unit tests, use `make test`.

To run the end-to-end JavaScript tests, first install fresh with with `./install-local.sh`. Then, run `npm test`.
