import { middle as middle_a } from "~/middle-a/middle";
import { middle as middle_b } from "~/middle-b/middle";

export function upper() {
    console.log("in //:upper");
    middle_a();
    middle_b();
}
