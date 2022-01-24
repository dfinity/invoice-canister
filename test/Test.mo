import ActorSpec "./utils/ActorSpec";
import Temp "../src/invoice/Temp";

type Group = ActorSpec.Group;

let assertTrue = ActorSpec.assertTrue;
let describe = ActorSpec.describe;
let it = ActorSpec.it;
let pending = ActorSpec.pending;
let run = ActorSpec.run;

run([
  describe("Temp", [
    describe("sayFoo", [
      it("should return foo", do {
        let foo = Temp.sayFoo();
        assertTrue(true)
      }),
    ]),
  ]),
]);
