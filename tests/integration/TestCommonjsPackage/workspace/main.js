const { lib_hello } = require("~/lib/hello");

exports.main = function () {
	console.log("in //:hello");
	lib_hello();
}
