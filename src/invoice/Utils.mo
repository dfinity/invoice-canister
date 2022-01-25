import T "./Types";
import A "./Account";
import Hex "./Hex";
import SHA224 "./SHA224";
import CRC32 "./CRC32";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";

module {
    type AccountIdentifier = T.AccountIdentifier;
    public func accountIdentifierToBlob (identifier: AccountIdentifier) : Blob {
        switch identifier {
            case(#text(identifier)){
                switch (Hex.decode(identifier)) {
                    case(#ok v){
                        return Blob.fromArray(v);
                    };
                    case(#err _){
                        return "";
                    };
                };
            };
            case(#principal(identifier)){
                return Principal.toBlob(identifier);
            };
            case(#blob(identifier)){
                return identifier;
            };
        };
    };
    public func accountIdentifierToText (identifier: AccountIdentifier) : Text {
        switch identifier {
            case(#text(identifier)){
                return identifier;
            };
            case(#principal(identifier)){
                return Principal.toText(identifier);
            };
            case(#blob(identifier)){
                return Hex.encode(Blob.toArray(identifier));
            };
        };
    };

    type GenerateInvoiceSubaccountArgs = {
        caller: Principal;
        id: Nat;
    };
    // Generate an invoice ID using hashed values from the invoice arguments
    public func generateInvoiceSubaccount (args: GenerateInvoiceSubaccountArgs) : Blob {
        let idHash = SHA224.Digest();
        // Length of domain separator
        idHash.write([0x0A]);
        // Domain separator
        idHash.write(Blob.toArray(Text.encodeUtf8("invoice-id")));
        // Counter as Nonce
        idHash.write([Nat8.fromNat(args.id)]);
        // Principal of caller
        idHash.write(Blob.toArray(Principal.toBlob(args.caller)));

        let hashSum = idHash.sum();
        let crc32Bytes = A.beBytes(CRC32.ofArray(hashSum));
        let buf = Buffer.Buffer<Nat8>(32);
        let blob = Blob.fromArray(Array.append(crc32Bytes, hashSum));

        return blob;
    };
}
