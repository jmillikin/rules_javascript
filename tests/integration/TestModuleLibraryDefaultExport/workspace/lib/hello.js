import hello_impl from "~/hello_impl";

function lib_hello() {
    console.log("in //lib:hello");
    hello_impl();
}

export { lib_hello as default };
