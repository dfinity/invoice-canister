# dfx canister call invoice accountIdentifierToBlob '(variant {"text" = "F482E833ADB604E72AF08504AAA46C0BB6D51706CA9C4BB83F79A8F7393171B2"})'


dfx canister call ledger transfer '( record { memo = 0; amount = record { e8s = 10_000_000_000 }; fee = record { e8s = 10000 }; to = blob "a\8b\b6\c4_w<\f5\038\15 5\17\f7\e7Wv\eb\13s\8a@AA\9f\0b\92\0c\d4\0bG" } )'
