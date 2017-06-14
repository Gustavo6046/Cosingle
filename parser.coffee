format = require('string-format')
format.extend(String.prototype)

bestOperand = (expr) ->
    possible = []

    for opt in operandTypes
        if opt.test(expr)
            possible.push(opt)

    c = possible.sort((ot, ot2) -> ot2.score - ot.score)[0]
    return new c(expr)

findOperator = (char) ->
    for o in operators
        if char in o.chars
            return o

    return null

class ExpressionBlock
    constructor: (@left, @char, @right) ->

    valueOf: =>
        @solve()

    solve: =>
        l = @left

        while typeof l == "object" and l.solve?
            l = l.solve()

        r = @right
        while typeof r == "object" and r.solve?
            r = r.solve()

        res = l.operate(@, [l, r], @char)

        return res

    stepSolve: (stepFunc) =>
        l = @left

        while l.stepSolve?
            l = l.stepSolve(stepFunc)

        r = @right
        if r?
            while r.stepSolve?
                r = r.stepSolve(stepFunc)

        console.log("Solving #{l?.value} #{@char} #{r?.value}...")

        if r?
            res = l.operate(@, [l, r], @char)

        else
            res = l.operate(@, [l], @char)

        if res.solve?
            res = res.stepSolve(stepFunc)

        if stepFunc?
            step = []

            if r?
                for x in findOperator(@char).step
                    if typeof x == "function"
                        step.push(x(l.value, r.value, res.value))

                    else
                        step.push(x.format({l: l.value, r: r.value, result: res.value}))

            else
                for x in findOperator(@char).step
                    if typeof x == "function"
                        step.push(x(l.value, null, res.value))

                    else
                        step.push(x.format({l: l.value, r: null, result: res.value}))

            stepFunc(step.join("\n"))

        return res

class Operand
    constructor: (@value) ->

    @score: 0

    @test: (expr) ->
        return true

    operating: (block, others, caller, char) ->

    precedence: (char) ->
        op = findOperator(char)

        return op.precedence

    operate: (block, others, char) =>
        op = findOperator(char)

        for o in others
            if not o is @
                o.operating(others, @, char)

        return bestOperand(op.solver.apply(this, others))

    toString: =>
        return @value.toString()

    valueOf: =>
        return +@value

class AlgebraicOperand extends Operand
    constructor: (@value) ->
        groups = @value.match(new RegExp("(\\d*)[#{['\\' + a.toString() for a in operators[0].chars.join('')]}]?([a-zA-Z]+)", "i"))

        @multiplier = groups[1]

        if @multiplier == ""
            @multiplier = 1

        @letters = groups[2]
        @diff = 0
        @exponent = 1

    @score: 10

    @test: (expr) ->
        r = new RegExp("(\\d*)[#{['\\' + a.toString() for a in operators[0].chars.join('')]}]?([a-zA-Z]+)", "i").test(expr)
        return r

    operating: (block, others, caller, char) =>
        return @operate(block, others, char)

    operate: (block, others, char) =>
        for o in others
            if o isnt @
                other = o

        if char == "="
            @definition = Math.pow(((+other.value + @diff) / @multiplier), 1 / @exponent)
            return new ExpressionBlock(bestOperand(@exponent), "$", new ExpressionBlock(new ExpressionBlock(other, "+", bestOperand(@diff)), "/", bestOperand(@multiplier)))

        else if char == "@"
            return super.operate(block, others, "@")

        else
            subexp = block
            othersub = []
            op = findOperator(char)
            differences = ""

            if others.length == 2
                if op.name == "Power"
                    @exponent += +(other.value) - 1
                    return @

                else if op.name == "Root"
                    @exponent -= +(other.value) - 1
                    return @

                else if op.name == "Subtraction"
                    @diff += +(other.value)
                    return @

                else if op.name == "Addition"
                    @diff -= +(other.value)
                    return @

                else
                    throw new Error("Unsupported algebraic operation!")
                    return @

    valueOf: (a) =>
        if @definition?
            return @definition

        else
            throw new Error("#{@value} is a variable, undefined expression!")

mathFuncs = {
    "sin": Math.sin
    "cos": Math.cos
    "tan": Math.tan
}

operators = [
    {
        name: "Multiplication"
        numargs: 2
        description: "Multiply two numbers."
        step: [
            "Multiply {l} and {r}:",
            "",
            "   {l} × {r} = {result}"
        ]
        precedence: 29
        chars: ["×", ".", "*"]

        solver: (a, b) ->
            +a * +b
    }
    {
        name: "Sum"
        numargs: 2
        description: "Sum two numbers."
        step: [
            "Sum {l} and {r}:",
            "",
            "   {l} + {r} = {result}"
        ]
        precedence: 30
        chars: ["+"]

        solver: (a, b) ->
            +a + +b
    }
    {
        name: "Function"
        numargs: 2
        description: "Call the math function of some name."
        step: [
            "Call {l} on {r}.",
            "",
            "   {l}({r}) = {result}"
        ]
        precedence: 5
        chars: ["@"]

        solver: (a, b) ->
            a = a.toString()

            if a in Object.keys(mathFuncs)
                return mathFuncs[a](b)

            else
                throw Error("No such function '#{a}'!")
    }
    {
        name: "Equal"
        numargs: 2
        description: "Define an algebraic variable."
        step: [
            "Define {l} equals {r}.",
            "",
            "   {l} = {r}; {l} = {result}"
        ]
        precedence: 70
        chars: ["="]

        solver: (a, b) ->
            return a
    }
    {
        name: "Subtraction"
        numargs: 2
        description: "Subtract a number by another one."
        step: [
            "Subtract {l} by {r}:",
            "",
            "   {l} - {r} = {result}"
        ]
        precedence: 30
        chars: ["-"]

        solver: (a, b) ->
            +a - +b
    }
    {
        name: "Division"
        numargs: 2
        description: "Divide a number by another one."
        step: [
            "Divide {l} by {r}:",
            "",
            "   {l}",
            (l, r, result) -> "   {a} = {result}".format({result: result, a: "~".repeat(if l.length > r.length then l.length else r.length)})
            "   {r}"
        ]
        precedence: 29
        chars: ["/", ":"]

        solver: (a, b) ->
            +a / +b
    }
    {
        name: "Power"
        numargs: 2
        description: "Raise a number to the power of some other number."
        step: [
            "Raise {l} to the power of {r}:",
            "",
            "   {l}´{r} = {result}"
        ]
        precedence: 28
        chars: ["^", "´"]

        solver: (a, b) ->
            Math.pow(+a, +b)
    }
    {
        name: "Root"
        numargs: 2
        description: "Perform a n-th root in a variable."
        step: [
            "Perform a {l}-root on {r}:",
            "",
            "   {l}√{r} = {result}"
        ]
        precedence: 28
        chars: ["$", "√"]

        solver: (a, b) ->
            Math.pow(+b, 1 / +a)
    }
]

parseExpr = (expr) ->
    curr = ""
    subexp = ""
    operands = []
    oper = null
    parens = 0
    pos = 0
    ops = 0

    console.log("Parsing #{expr}...")

    expr = expr.replace(/\s/g, "")

    for ch in expr
        if parens > 0
            if ch == ")"
                if parens == 1
                    r = parseExpr(subexp)
                    r.paren = true
                    curr = r
                    operands.push(r)
                    subexp = ""

                else
                    subexp += ch

                parens--

            else
                if ch == "("
                    parens++

                subexp += ch

        else
            op = findOperator(ch)

            if op?
                if op.numargs == 1
                    if curr != ""
                        throw new Error("Unary operator must be at the left side of an operand, not right! (at #{expr}, operator #{ch} at position #{pos})")

                    else
                        oper = ch

                else
                    if ops == 0
                        if curr != ""
                            if typeof curr != "object"
                                operands.push(bestOperand(curr))

                            else
                                operands.push(curr)

                            curr = ""

                        else
                            throw new Error("Binary operators need a non-null left value! (at #{expr}, operator #{ch} at position #{pos})")

                        oper = ch

                    else
                        if typeof operands[0] == "object" and operands[0].solve?
                            if findOperator(operands[0].char).precedence > findOperator(ch).precedence or operator[0]?.paren
                                operands = [new ExpressionBlock(operands[0].left, operands[0].char, new ExpressionBlock(operands[0].right, ch, curr))]

                            else
                                operands = [new ExpressionBlock(operands[0], ch, curr)]

                ops++

            else
                if ch == "("
                    parens++

                else if ch == ")"
                    throw new Error("Unmatched ')' (at #{expr}, position #{pos})")

                else
                    curr += ch

        pos += 1

    if typeof curr == "ExpressionBlock"
        return curr

    else
        if findOperator(oper).numargs == 1 or not operands[0]?
            if curr == ""
                throw new Error("Unary operators need a single value! (at #{expr}, operator #{oper} at position #{pos})")

            if typeof curr != "object"
                curr = bestOperand(curr)

            return new ExpressionBlock(curr, oper, undefined)

        else
            if curr == ""
                throw new Error("Binary operators need a non-null right value! (at #{expr}, operator #{oper} at position #{pos})")

            if typeof curr != "object"
                curr = bestOperand(curr)

            if typeof operands[0] == "object" and operands[0].solve?
                if findOperator(operands[0].char).precedence > findOperator(oper).precedence and operands[0]?.paren
                    return new ExpressionBlock(operands[0].left, operands[0].char, new ExpressionBlock(operands[0].right, oper, curr))

                else
                    return new ExpressionBlock(operands[0], oper, curr)

            else if typeof(operands[0]) == "object"
                return new ExpressionBlock(operands[0], oper, curr)

            else
                return new ExpressionBlock(bestOperand(operands[0]), oper, curr)

operandTypes = [Operand, AlgebraicOperand]

module.exports = {
    operators: operators
    parseExpr: parseExpr
    ExpressionBlock: ExpressionBlock
    Operand: Operand
    AlgebraicOperand: AlgebraicOperand
    findOperator: findOperator
    bestOperand: bestOperand
    operandTypes: operandTypes
}