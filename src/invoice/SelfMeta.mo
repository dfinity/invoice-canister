import Principal "mo:base/Principal"
module {
    public type Meta = {
        canisterId : Principal;
    };
    public func getMeta () : Meta {
        return {
            canisterId: Principal = Principal.fromText("r7inp-6aaaa-aaaaa-aaabq-cai");
        };
    };
}
