export DESTINATION='blob "^\1f\f7\ce{\1f\e6\f8\ad\5c\f5T\1e\84\92\fd\e9gJ\01\96\f7\ae\0c\ad\ba\cf\7f\b3\60\e8R"'


dfx canister call ledger transfer '( record { memo = 0; amount = record { e8s = 100000000 }; fee = record { e8s = 10000 }; to = blob "^\1f\f7\ce{\1f\e6\f8\ad\5c\f5T\1e\84\92\fd\e9gJ\01\96\f7\ae\0c\ad\ba\cf\7f\b3\60\e8R" } )'
