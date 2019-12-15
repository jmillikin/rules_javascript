const middle_a = require("~/middle-a/middle");
const middle_b = require("~/middle-b/middle");

exports.upper = function () {
    console.log("in //:upper");
    middle_a.middle();
    middle_b.middle();
}
