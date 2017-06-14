parser = require("./parser.js")
steps = []

res = parser.parseExpr(process.argv.slice(2).join(" ")).stepSolve((step, a, b, op) ->
    steps.push(step)
)

console.log("Result: #{res}\n\n===DETAILED WALKTHROUGH===\n\n")
console.log(steps.join("\n\n========\n\n"))