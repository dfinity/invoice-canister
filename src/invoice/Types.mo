module {
    public type Token = {
        symbol: Text;
    };
    public type TokenVerbose = {
        symbol: Text;
        decimals: Int;
        meta: ?{
            Issuer: Text;
        };
    };
    public type AccountIdentifier = {
        #text: Text;
        #principal: Principal;
        #blob: Blob;
    };
    public type Details = {
        description: Text;
        meta: Blob;
    };
};
