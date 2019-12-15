import { hello_impl } from "~/hello_impl";

export function lib_hello() {
    console.log("in //lib:hello");
    hello_impl();
}
