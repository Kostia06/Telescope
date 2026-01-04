import Cocoa
import Foundation
import JavaScriptCore

class CalcView: NSView, NSTextFieldDelegate {
    private var inputField: NSTextField!
    private var resultLabel: NSTextField!
    private var historyLabel: NSTextField!
    private var jsContext: JSContext!

    // Answer history
    private var answerHistory: [Double] = []
    private var lastAnswer: Double = 0

    var onClose: (() -> Void)?
    var onEscape: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupJSContext()
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupJSContext()
        setupUI()
    }

    private func setupJSContext() {
        jsContext = JSContext()
        // Add comprehensive math functions
        let mathSetup = """
            // Constants
            var pi = Math.PI;
            var e = Math.E;
            var phi = 1.6180339887498949;  // Golden ratio
            var tau = Math.PI * 2;

            // Basic functions
            var sqrt = Math.sqrt;
            var cbrt = Math.cbrt;
            var pow = Math.pow;
            var abs = Math.abs;
            var sign = Math.sign;

            // Exponential & Logarithmic
            var exp = Math.exp;
            var expm1 = Math.expm1;
            var log = Math.log;
            var ln = Math.log;
            var log10 = Math.log10;
            var log2 = Math.log2;
            var log1p = Math.log1p;

            // Trigonometric (radians)
            var sin = Math.sin;
            var cos = Math.cos;
            var tan = Math.tan;
            var asin = Math.asin;
            var acos = Math.acos;
            var atan = Math.atan;
            var atan2 = Math.atan2;

            // Hyperbolic
            var sinh = Math.sinh;
            var cosh = Math.cosh;
            var tanh = Math.tanh;
            var asinh = Math.asinh;
            var acosh = Math.acosh;
            var atanh = Math.atanh;

            // Rounding
            var floor = Math.floor;
            var ceil = Math.ceil;
            var round = Math.round;
            var trunc = Math.trunc;

            // Min/Max
            var min = Math.min;
            var max = Math.max;

            // Utility functions
            var hypot = Math.hypot;
            var random = Math.random;

            // Degree/Radian conversion
            function deg(x) { return x * Math.PI / 180; }
            function rad(x) { return x * 180 / Math.PI; }

            // Trig in degrees
            function sind(x) { return Math.sin(x * Math.PI / 180); }
            function cosd(x) { return Math.cos(x * Math.PI / 180); }
            function tand(x) { return Math.tan(x * Math.PI / 180); }

            // Factorial
            function fact(n) {
                if (n < 0) return NaN;
                if (n === 0 || n === 1) return 1;
                if (n > 170) return Infinity;
                var result = 1;
                for (var i = 2; i <= n; i++) result *= i;
                return result;
            }
            var factorial = fact;

            // Combinations and Permutations
            function nCr(n, r) { return fact(n) / (fact(r) * fact(n - r)); }
            function nPr(n, r) { return fact(n) / fact(n - r); }
            var C = nCr;
            var P = nPr;

            // Percentage
            function pct(x) { return x / 100; }

            // Answer placeholder (will be set dynamically)
            var ans = 0;
            var ans1 = 0;
            var ans2 = 0;
            var ans3 = 0;
        """
        jsContext.evaluateScript(mathSetup)
    }

    private func setupUI() {
        wantsLayer = true
        layer?.drawsAsynchronously = true

        let containerPadding: CGFloat = 18

        // History label - shows previous answer - Apple style
        historyLabel = NSTextField(labelWithString: "")
        historyLabel.frame = NSRect(x: containerPadding, y: 88, width: bounds.width - (containerPadding * 2), height: 16)
        historyLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        historyLabel.textColor = NSColor.tertiaryLabelColor
        historyLabel.alignment = .right
        historyLabel.isEditable = false
        historyLabel.isBordered = false
        historyLabel.drawsBackground = false
        addSubview(historyLabel)

        // Input field - Apple style
        inputField = NSTextField(frame: NSRect(x: containerPadding, y: 58, width: bounds.width - (containerPadding * 2), height: 32))
        inputField.placeholderString = "sqrt(ans) + 10"
        inputField.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        inputField.focusRingType = .none
        inputField.isBordered = false
        inputField.isBezeled = false
        inputField.drawsBackground = false
        inputField.delegate = self
        inputField.textColor = NSColor.labelColor
        inputField.alignment = .left

        let placeholderAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        ]
        inputField.placeholderAttributedString = NSAttributedString(string: "sqrt(ans) + 10", attributes: placeholderAttrs)
        addSubview(inputField)

        // Separator line
        let separator = NSBox(frame: NSRect(x: containerPadding, y: 54, width: bounds.width - (containerPadding * 2), height: 1))
        separator.boxType = .separator
        separator.alphaValue = 0.2
        addSubview(separator)

        // Result label - large, prominent - Apple style accent color
        resultLabel = NSTextField(labelWithString: "")
        resultLabel.frame = NSRect(x: containerPadding, y: 12, width: bounds.width - (containerPadding * 2), height: 38)
        resultLabel.font = NSFont.monospacedSystemFont(ofSize: 32, weight: .light)
        resultLabel.textColor = NSColor.controlAccentColor
        resultLabel.alignment = .left
        resultLabel.isSelectable = true
        resultLabel.isEditable = false
        resultLabel.isBordered = false
        resultLabel.isBezeled = false
        resultLabel.drawsBackground = false
        addSubview(resultLabel)

        updateHistoryLabel()
    }

    @objc private func calculate() {
        let expression = inputField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !expression.isEmpty else {
            resultLabel.stringValue = ""
            resultLabel.textColor = NSColor.controlAccentColor
            return
        }

        // Evaluate using JavaScript
        if let result = evaluateExpression(expression) {
            resultLabel.stringValue = "= " + formatNumber(result)
            resultLabel.textColor = NSColor.controlAccentColor
        } else {
            resultLabel.stringValue = ""
            resultLabel.textColor = NSColor.controlAccentColor
        }
    }

    private func updateAnswerVariables() {
        // Update JavaScript context with answer history
        jsContext.setObject(lastAnswer, forKeyedSubscript: "ans" as NSString)

        if answerHistory.count >= 1 {
            jsContext.setObject(answerHistory[answerHistory.count - 1], forKeyedSubscript: "ans1" as NSString)
        }
        if answerHistory.count >= 2 {
            jsContext.setObject(answerHistory[answerHistory.count - 2], forKeyedSubscript: "ans2" as NSString)
        }
        if answerHistory.count >= 3 {
            jsContext.setObject(answerHistory[answerHistory.count - 3], forKeyedSubscript: "ans3" as NSString)
        }
    }

    private func updateHistoryLabel() {
        if lastAnswer != 0 {
            historyLabel.stringValue = "ans = \(formatNumber(lastAnswer))"
        } else if !answerHistory.isEmpty {
            historyLabel.stringValue = "ans = \(formatNumber(answerHistory.last ?? 0))"
        } else {
            historyLabel.stringValue = ""
        }
    }

    private func saveAnswer(_ value: Double) {
        guard !value.isNaN && !value.isInfinite else { return }
        lastAnswer = value
        answerHistory.append(value)
        if answerHistory.count > 10 {
            answerHistory.removeFirst()
        }
        updateAnswerVariables()
        updateHistoryLabel()
    }

    private func evaluateExpression(_ expression: String) -> Double? {
        // Update answer variables before evaluation
        updateAnswerVariables()

        // First, handle factorial notation: convert "5!" or "(5+2)!" to "fact(5)" or "fact(5+2)"
        var processedExpression = expression

        // Handle factorial with parentheses like (5+2)!
        if let parenFactPattern = try? NSRegularExpression(pattern: "\\(([^)]+)\\)!") {
            let range = NSRange(processedExpression.startIndex..., in: processedExpression)
            processedExpression = parenFactPattern.stringByReplacingMatches(
                in: processedExpression,
                range: range,
                withTemplate: "fact($1)"
            )
        }

        // Handle simple factorial like 5!
        if let simpleFactPattern = try? NSRegularExpression(pattern: "(\\d+)!") {
            let range = NSRange(processedExpression.startIndex..., in: processedExpression)
            processedExpression = simpleFactPattern.stringByReplacingMatches(
                in: processedExpression,
                range: range,
                withTemplate: "fact($1)"
            )
        }

        // Clean the expression
        processedExpression = processedExpression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "^", with: "**")
            .replacingOccurrences(of: "π", with: "pi")
            .replacingOccurrences(of: "τ", with: "tau")
            .replacingOccurrences(of: "φ", with: "phi")

        // Handle percentage at end of expression like "50% of 200" or "20%"
        if let pctPattern = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)%\\s*(?:of\\s+)?(\\d+(?:\\.\\d+)?)") {
            let range = NSRange(processedExpression.startIndex..., in: processedExpression)
            processedExpression = pctPattern.stringByReplacingMatches(
                in: processedExpression,
                range: range,
                withTemplate: "($1/100)*$2"
            )
        }

        // Simple percentage like "20%" -> 0.2
        if let simplePctPattern = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)%(?![\\d\\w])") {
            let range = NSRange(processedExpression.startIndex..., in: processedExpression)
            processedExpression = simplePctPattern.stringByReplacingMatches(
                in: processedExpression,
                range: range,
                withTemplate: "($1/100)"
            )
        }

        // Evaluate with JavaScript
        guard let result = jsContext.evaluateScript(processedExpression) else { return nil }

        if result.isNumber {
            return result.toDouble()
        }

        return nil
    }

    private func formatNumber(_ number: Double) -> String {
        if number.isNaN || number.isInfinite {
            return "Error"
        }

        // Check if it's a whole number
        if number.truncatingRemainder(dividingBy: 1) == 0 && abs(number) < 1e12 {
            return String(format: "%.0f", number)
        }

        // Use scientific notation for very large or very small numbers
        if abs(number) >= 1e10 || (abs(number) < 0.0001 && number != 0) {
            return String(format: "%.4e", number)
        }

        // Regular decimal - remove trailing zeros
        let formatted = String(format: "%.8f", number)
        var result = formatted
        while result.hasSuffix("0") && result.contains(".") {
            result.removeLast()
        }
        if result.hasSuffix(".") {
            result.removeLast()
        }
        return result
    }

    func focusTextField() {
        window?.makeFirstResponder(inputField)
    }

    func reset() {
        inputField.stringValue = ""
        resultLabel.stringValue = ""
        resultLabel.textColor = NSColor.white
        updateHistoryLabel()
    }

    func copyResult() {
        let resultString = resultLabel.stringValue.replacingOccurrences(of: "= ", with: "")
        guard !resultString.isEmpty, resultString != "Error" else { return }

        // Save to answer history
        if let value = Double(resultString) {
            saveAnswer(value)
        }

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(resultString, forType: .string)
    }

    // MARK: - NSTextFieldDelegate
    func controlTextDidChange(_ obj: Notification) {
        calculate()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onEscape?()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            copyResult()
            inputField.stringValue = ""
            resultLabel.stringValue = ""
            return true
        }
        return false
    }
}
