# dfx canister call invoice accountIdentifierToBlob '(variant {"text" = "F482E833ADB604E72AF08504AAA46C0BB6D51706CA9C4BB83F79A8F7393171B2"})'


dfx canister call ledger transfer '( record { memo = 0; amount = record { e8s = 10_000_000_000 }; fee = record { e8s = 10000 }; to = blob "o\ff\87\ed\f5\06\9b\84\ce\87\1a\cf\cd\8f\80\11\14I\1d/\84\adnn\90\92\89P\ec\a4\91\f0" } )'
