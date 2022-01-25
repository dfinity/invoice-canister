import A "../src/invoice/Account";
import U "../src/invoice/Utils";
import Hex "../src/invoice/Hex";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";

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
        let blob = Hex.decode("082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5");
        switch(blob){
          case (#err _){
            false;
          };
          case (#ok b){
            let text = U.accountIdentifierToText(#blob(Blob.fromArray(b)));
            assertTrue(text == "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5");
          };
        };

      }),
      skip("should convert a #text accountIdentifier to Blob", do {
        assertTrue(true);
      }),
      skip("should convert a #principal accountIdentifier to Blob", do {
        assertTrue(true);
      }),
      skip("should convert a #blob accountIdentifier to Blob", do {
        assertTrue(true);
      }),
    ]),
    describe("Invoice ID", [
      skip("should generate a valid invoice ID", do {
        assertTrue(true);
      }),
    ])
  ]),
]);
