import A "../src/invoice/Account";
import U "../src/invoice/Utils";
import Hex "../src/invoice/Hex";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Result "mo:base/Result";

import ActorSpec "./utils/ActorSpec";
type Group = ActorSpec.Group;

let assertTrue = ActorSpec.assertTrue;
let describe = ActorSpec.describe;
let it = ActorSpec.it;
let skip = ActorSpec.skip;
let pending = ActorSpec.pending;
let run = ActorSpec.run;

let testPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
let testCaller = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
let defaultSubaccount = A.defaultSubaccount();

func defaultAccountBlob() : Blob {
    let decoded = Hex.decode("082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5");
    switch(decoded){
      case(#err _) {
        return Text.encodeUtf8("");
      };
      case(#ok arr) {
        return Blob.fromArray(arr);
      };
    }
};

run([
  describe("ICP Tests", [
    describe("Account Identifiers Utilities", [
      it("should generate a valid account identifier", do {
        let account = A.accountIdentifier(testPrincipal, defaultSubaccount);
        assertTrue(A.validateAccountIdentifier(account));
      }),
      it("should convert a principal to a subaccount", do {
        let subaccount = A.principalToSubaccount(testCaller);
        // Subaccounts should have a length of 32
        assertTrue(subaccount.size() == 32);
      }),
      it("should generate a valid default account for a caller", do {
        let subaccount = A.principalToSubaccount(testCaller);
        let accountIdentifier = A.accountIdentifier(testPrincipal, subaccount);
        assertTrue(A.validateAccountIdentifier(accountIdentifier));
      }),
      it("should convert a #text accountIdentifier to Text", do {
        let account = A.accountIdentifier(testPrincipal, defaultSubaccount);
        let text = U.accountIdentifierToText(#blob(account));
        assertTrue(text == "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5");
      }),
      skip("should convert a #principal accountIdentifier to Text", do {
        // TODO - figure out what this behavior is supposed to be
        assertTrue(true);
      }),
      it("should convert a #blob accountIdentifier to Text", do {
        let defaultBlob = defaultAccountBlob();
        let text = U.accountIdentifierToText(#blob(defaultBlob));
        assertTrue(text == "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5");
      }),
      it("should convert a #text accountIdentifier to Blob", do {
        let id = #text("082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5");
        let blob = U.accountIdentifierToBlob(id);
        let defaultBlob = defaultAccountBlob();
        assertTrue(blob == defaultBlob);
      }),
      skip("should convert a #principal accountIdentifier to Blob", do {
        // TODO - figure out what this behavior is supposed to be
        assertTrue(true);
      }),
      it("should convert a #blob accountIdentifier to Blob", do {
        let defaultBlob = defaultAccountBlob();
        let id = #blob(defaultBlob);
        let blob = U.accountIdentifierToBlob(id);
        assertTrue(blob == defaultBlob);
      }),
    ]),
    describe("Invoice Subaccount Creation", [
      it("should generate a valid invoice ID", do {
        let subaccount = U.generateInvoiceSubaccount({
          caller = testCaller;
          id = 0;
        });
        
        assertTrue(A.validateAccountIdentifier(subaccount));
      }),
    ])
  ]),
]);
