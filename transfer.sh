# dfx canister call invoice accountIdentifierToBlob '(variant {"text" = "F482E833ADB604E72AF08504AAA46C0BB6D51706CA9C4BB83F79A8F7393171B2"})'


dfx canister call ledger transfer '( record { memo = 0; amount = record { e8s = 10_000_000_000 }; fee = record { e8s = 10000 }; to = blob "\e6j/\05\e4\bf\16\f6\e6\9a\f9U\f2z>\a4f\cb\ab\b3\13\f5/\c5\abU\c0$Js\d7\f4" } )'
