const { hello_impl } = require("~/hello_impl");

exports.lib_hello = function () {
    console.log("in //lib:hello");
    hello_impl();
}
