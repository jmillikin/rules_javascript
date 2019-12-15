const typescript = require("typescript");
const tsserver = require("typescript/lib/tsserverlibrary");

exports.lib_hello = function () {
    console.log("in //lib:hello");
    console.log("typescript.version: ", typescript.version);
    console.log("tsserver.version: ", tsserver.version);
}
