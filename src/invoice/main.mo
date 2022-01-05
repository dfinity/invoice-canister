import Ledger    "canister:ledger";

import Debug     "mo:base/Debug";
import Error     "mo:base/Error";
import Int       "mo:base/Int";
import HashMap   "mo:base/HashMap";
import List      "mo:base/List";
import Nat64     "mo:base/Nat64";
import Principal "mo:base/Principal";
import Time      "mo:base/Time";

import Account   "./Account";

actor Invoice {
    public query func canisterAccount() : async Account.AccountIdentifier {
        myAccountId()
    };

        // Returns the default account identifier of this canister.
    func myAccountId() : Account.AccountIdentifier {
        Account.accountIdentifier(Principal.fromActor(Self), Account.defaultSubaccount())
    };
}
