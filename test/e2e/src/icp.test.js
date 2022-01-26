const identityUtils = require("./utils/identity");
const { defaultActor } = identityUtils;

describe("ICP Tests", () => {
  it("should fetch the name of the caller", async () => {
    let identifier = await defaultActor.get_caller_identifier({
      token: {
        symbol: "ICP",
      },
    });
    if ("Ok" in identifier) {
      expect(identifier.Ok.accountIdentifier).toStrictEqual({
        // prettier-ignore
        "text": "f834bd307422e47225d915888092810b3eae9daea5e54b67dfc99799698f8eea",
      });
    } else {
      throw new Error("identifier.Err.message");
    }
  });
});
