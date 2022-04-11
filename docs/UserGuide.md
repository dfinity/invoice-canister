# User Guide

## How to use the Invoice Canister in your project

TODO: Write how to use the Invoice Canister in your project

## Constraints
In order to keep the size of the state predictable we set constraints on the size of various fields in invoice creation arguments. The following table lists the constraints.

| Field                  | Max Size |
|------------------------|----------|
| `Meta`                 | 32_000   |
| `description`          | 256      |
| `canGet`               | 256      |
| `canVerify`            | 256      |
| `creation_allowlist`   | 256      |

Given these constraints, we can estimate that the canister can safely hold 30,000 invoices. This is a reasonable upper bound for the number of invoices that can be stored in the canister until we add in the ability to archive and scale the provider automatically.

## Safe deployments
The canister allows invoice creation with an allowlist. Since the canister is holding ICP custodially, you should only allow your own accounts to create invoices, for maximum safety to your users. After the canister is uploaded, call the `authorize_creation` method with the principals of your canisters or admin accounts to add them to the allowlist. 

We recommend you publish your fork or clone of this project on GitHub and use the https://docs.covercode.ooo/ guide provide reproducibible builds for any and all financial applications. If it is possible, consider removing all controllers except for the [blackhole canister](https://github.com/ninegua/ic-blackhole).
