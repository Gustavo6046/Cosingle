// Generated by CoffeeScript 1.12.6
var parser, res, steps;

parser = require("./parser.js");

steps = [];

res = parser.parseExpr(process.argv.slice(2).join(" ")).stepSolve(function(step, a, b, op) {
  return steps.push(step);
});

console.log("Result: " + res + "\n\n===DETAILED WALKTHROUGH===\n\n");

console.log(steps.join("\n\n========\n\n"));