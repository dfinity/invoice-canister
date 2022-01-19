# dfx canister call invoice accountIdentifierToBlob '(variant {"text" = "F482E833ADB604E72AF08504AAA46C0BB6D51706CA9C4BB83F79A8F7393171B2"})'


dfx canister call ledger transfer '( record { memo = 0; amount = record { e8s = 10_000_000_000 }; fee = record { e8s = 10000 }; to = blob "\88E\dd\ed\c58+\d9{\f6\1e\80\f3EE\ab\11\e7\98\c0\22\8b\baW\e6f\d03\9f>\e8&" } )'
