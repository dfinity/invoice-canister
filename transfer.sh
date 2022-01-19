# dfx canister call invoice accountIdentifierToBlob '(variant {"text" = "F482E833ADB604E72AF08504AAA46C0BB6D51706CA9C4BB83F79A8F7393171B2"})'


dfx canister call ledger transfer '( record { memo = 0; amount = record { e8s = 10_000_000_000 }; fee = record { e8s = 10000 }; to = blob "\acr3v\a0m-\b8\ac\cb0\96 \90\8b\cc-e3\e2Q\da\f1\a0\08\a4&sZ\af\f7\86" } )'
