// Fixture: known bad patterns for rule engine validation
const key = "AKIAIOSFODNN7EXAMPLE1"; // SEC-010: AWS key
eval("alert(1)"); // SEC-011: eval
console.log("debug"); // QUAL-011: console.log
fetch("http://api.example.com").then(res => res.json()); // STYLE-010: .then()
import { foo } from "../../../deeply/nested/module"; // STYLE-011: deep import
// TODO: fix this later // QUAL-014: technical debt
