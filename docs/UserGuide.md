# User Guide

## How to use the Invoice Canister in your project

TODO: Write how to use the Invoice Canister in your project

## Constraints
In order to keep the size of the state predictable we set constraints on the size of various fields in invoice creation arguments. The following table lists the constraints.

| Field         | Max Size |
|---------------|----------|
| `Meta`        | 32_000   |
| `description` | 256      |
| `canGet`      | 256      |
| `canVerify`   | 256      |

Given these constraints, we can estimate that the canister can safely hold 30,000 invoices. This is a reasonable upper bound for the number of invoices that can be stored in the canister until we add in the ability to archive and scale the provider automatically.
