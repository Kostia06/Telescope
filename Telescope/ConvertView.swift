import Cocoa

class ConvertView: NSView, NSTextFieldDelegate {
    private var inputField: NSTextField!
    private var resultLabel: NSTextField!
    private var categoryButtons: [NSButton] = []
    private var selectedCategory: ConversionCategory = .length

    var onClose: (() -> Void)?
    var onEscape: (() -> Void)?

    enum ConversionCategory: String, CaseIterable {
        case length = "Length"
        case weight = "Weight"
        case temperature = "Temp"
        case volume = "Volume"
        case data = "Data"
        case time = "Time"
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true

        let padding: CGFloat = 16

        // Input field
        inputField = NSTextField(frame: NSRect(x: padding, y: 68, width: bounds.width - padding * 2, height: 28))
        inputField.placeholderString = "10 km to miles, 100 F to C, 1 GB to MB"
        inputField.font = NSFont.systemFont(ofSize: 14)
        inputField.focusRingType = .none
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.textColor = NSColor.labelColor
        inputField.delegate = self

        let placeholderAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: NSFont.systemFont(ofSize: 14)
        ]
        inputField.placeholderAttributedString = NSAttributedString(string: "10 km to miles, 100°F to C, 1 GB to MB", attributes: placeholderAttrs)
        addSubview(inputField)

        // Result label
        resultLabel = NSTextField(labelWithString: "")
        resultLabel.frame = NSRect(x: padding, y: 38, width: bounds.width - padding * 2, height: 26)
        resultLabel.font = NSFont.monospacedSystemFont(ofSize: 20, weight: .medium)
        resultLabel.textColor = NSColor.controlAccentColor
        addSubview(resultLabel)

        // Category buttons
        let categories = ConversionCategory.allCases
        let buttonWidth: CGFloat = 60
        let spacing: CGFloat = 6
        let totalWidth = CGFloat(categories.count) * buttonWidth + CGFloat(categories.count - 1) * spacing
        var x = (bounds.width - totalWidth) / 2

        for category in categories {
            let button = NSButton(frame: NSRect(x: x, y: 8, width: buttonWidth, height: 22))
            button.title = category.rawValue
            button.bezelStyle = .recessed
            button.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            button.target = self
            button.action = #selector(categoryTapped(_:))
            button.tag = categories.firstIndex(of: category) ?? 0

            if category == selectedCategory {
                button.state = .on
            }

            addSubview(button)
            categoryButtons.append(button)
            x += buttonWidth + spacing
        }
    }

    @objc private func categoryTapped(_ sender: NSButton) {
        let categories = ConversionCategory.allCases
        if sender.tag < categories.count {
            selectedCategory = categories[sender.tag]
            updateCategorySelection()
            convert()
        }
    }

    private func updateCategorySelection() {
        let categories = ConversionCategory.allCases
        for (index, button) in categoryButtons.enumerated() {
            button.state = categories[index] == selectedCategory ? .on : .off
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        convert()
    }

    private func convert() {
        let input = inputField.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        guard !input.isEmpty else {
            resultLabel.stringValue = ""
            return
        }

        // Try to parse the conversion
        if let result = parseAndConvert(input) {
            resultLabel.stringValue = result
            resultLabel.textColor = NSColor.controlAccentColor
        } else {
            resultLabel.stringValue = ""
        }
    }

    private func parseAndConvert(_ input: String) -> String? {
        // Pattern: "value unit to unit" or "value unit"
        let pattern = #"([\d.]+)\s*°?\s*([a-zA-Z]+)\s*(?:to|in|->|=)?\s*([a-zA-Z]*)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }

        guard let valueRange = Range(match.range(at: 1), in: input),
              let fromRange = Range(match.range(at: 2), in: input) else {
            return nil
        }

        let value = Double(input[valueRange]) ?? 0
        let fromUnit = String(input[fromRange]).lowercased()
        let toUnit: String? = match.range(at: 3).location != NSNotFound ?
            Range(match.range(at: 3), in: input).map { String(input[$0]).lowercased() } : nil

        // Length conversions
        let lengthResult = convertLength(value: value, from: fromUnit, to: toUnit)
        if let result = lengthResult { return result }

        // Weight conversions
        let weightResult = convertWeight(value: value, from: fromUnit, to: toUnit)
        if let result = weightResult { return result }

        // Temperature conversions
        let tempResult = convertTemperature(value: value, from: fromUnit, to: toUnit)
        if let result = tempResult { return result }

        // Volume conversions
        let volumeResult = convertVolume(value: value, from: fromUnit, to: toUnit)
        if let result = volumeResult { return result }

        // Data conversions
        let dataResult = convertData(value: value, from: fromUnit, to: toUnit)
        if let result = dataResult { return result }

        // Time conversions
        let timeResult = convertTime(value: value, from: fromUnit, to: toUnit)
        if let result = timeResult { return result }

        return nil
    }

    private func convertLength(value: Double, from: String, to: String?) -> String? {
        // Convert to meters first
        let toMeters: [String: Double] = [
            "m": 1, "meter": 1, "meters": 1,
            "km": 1000, "kilometer": 1000, "kilometers": 1000,
            "cm": 0.01, "centimeter": 0.01, "centimeters": 0.01,
            "mm": 0.001, "millimeter": 0.001, "millimeters": 0.001,
            "mi": 1609.344, "mile": 1609.344, "miles": 1609.344,
            "ft": 0.3048, "foot": 0.3048, "feet": 0.3048,
            "in": 0.0254, "inch": 0.0254, "inches": 0.0254,
            "yd": 0.9144, "yard": 0.9144, "yards": 0.9144
        ]

        guard let fromFactor = toMeters[from] else { return nil }

        let meters = value * fromFactor

        // If target unit specified
        if let target = to, !target.isEmpty, let toFactor = toMeters[target] {
            let result = meters / toFactor
            return formatResult(result, unit: target)
        }

        // Auto-convert to common units
        var results: [String] = []
        if from.hasPrefix("k") || from == "mi" || from == "mile" || from == "miles" {
            results.append(formatResult(meters / 1609.344, unit: "mi"))
            results.append(formatResult(meters / 1000, unit: "km"))
        } else {
            results.append(formatResult(meters / 0.3048, unit: "ft"))
            results.append(formatResult(meters * 100, unit: "cm"))
        }

        return results.joined(separator: " | ")
    }

    private func convertWeight(value: Double, from: String, to: String?) -> String? {
        // Convert to grams first
        let toGrams: [String: Double] = [
            "g": 1, "gram": 1, "grams": 1,
            "kg": 1000, "kilogram": 1000, "kilograms": 1000,
            "mg": 0.001, "milligram": 0.001,
            "lb": 453.592, "lbs": 453.592, "pound": 453.592, "pounds": 453.592,
            "oz": 28.3495, "ounce": 28.3495, "ounces": 28.3495
        ]

        guard let fromFactor = toGrams[from] else { return nil }

        let grams = value * fromFactor

        if let target = to, !target.isEmpty, let toFactor = toGrams[target] {
            return formatResult(grams / toFactor, unit: target)
        }

        // Auto-convert
        return "\(formatResult(grams / 453.592, unit: "lb")) | \(formatResult(grams / 1000, unit: "kg"))"
    }

    private func convertTemperature(value: Double, from: String, to: String?) -> String? {
        let fromTemp = from.replacingOccurrences(of: "°", with: "")

        var celsius: Double

        switch fromTemp {
        case "c", "celsius":
            celsius = value
        case "f", "fahrenheit":
            celsius = (value - 32) * 5 / 9
        case "k", "kelvin":
            celsius = value - 273.15
        default:
            return nil
        }

        if let target = to, !target.isEmpty {
            switch target {
            case "c", "celsius":
                return formatResult(celsius, unit: "°C")
            case "f", "fahrenheit":
                return formatResult(celsius * 9 / 5 + 32, unit: "°F")
            case "k", "kelvin":
                return formatResult(celsius + 273.15, unit: "K")
            default:
                return nil
            }
        }

        // Auto-convert
        let fahrenheit = celsius * 9 / 5 + 32
        let kelvin = celsius + 273.15
        return "\(formatResult(celsius, unit: "°C")) | \(formatResult(fahrenheit, unit: "°F")) | \(formatResult(kelvin, unit: "K"))"
    }

    private func convertVolume(value: Double, from: String, to: String?) -> String? {
        // Convert to liters
        let toLiters: [String: Double] = [
            "l": 1, "liter": 1, "liters": 1, "litre": 1,
            "ml": 0.001, "milliliter": 0.001,
            "gal": 3.78541, "gallon": 3.78541, "gallons": 3.78541,
            "qt": 0.946353, "quart": 0.946353,
            "pt": 0.473176, "pint": 0.473176,
            "cup": 0.236588, "cups": 0.236588,
            "floz": 0.0295735, "oz": 0.0295735
        ]

        guard let fromFactor = toLiters[from] else { return nil }

        let liters = value * fromFactor

        if let target = to, !target.isEmpty, let toFactor = toLiters[target] {
            return formatResult(liters / toFactor, unit: target)
        }

        return "\(formatResult(liters / 3.78541, unit: "gal")) | \(formatResult(liters, unit: "L"))"
    }

    private func convertData(value: Double, from: String, to: String?) -> String? {
        // Convert to bytes
        let toBytes: [String: Double] = [
            "b": 1, "byte": 1, "bytes": 1,
            "kb": 1024, "kilobyte": 1024,
            "mb": 1048576, "megabyte": 1048576,
            "gb": 1073741824, "gigabyte": 1073741824,
            "tb": 1099511627776, "terabyte": 1099511627776
        ]

        guard let fromFactor = toBytes[from] else { return nil }

        let bytes = value * fromFactor

        if let target = to, !target.isEmpty, let toFactor = toBytes[target] {
            return formatResult(bytes / toFactor, unit: target.uppercased())
        }

        // Auto format to appropriate unit
        if bytes >= 1099511627776 {
            return formatResult(bytes / 1099511627776, unit: "TB")
        } else if bytes >= 1073741824 {
            return formatResult(bytes / 1073741824, unit: "GB")
        } else if bytes >= 1048576 {
            return formatResult(bytes / 1048576, unit: "MB")
        } else if bytes >= 1024 {
            return formatResult(bytes / 1024, unit: "KB")
        }
        return formatResult(bytes, unit: "B")
    }

    private func convertTime(value: Double, from: String, to: String?) -> String? {
        // Convert to seconds
        let toSeconds: [String: Double] = [
            "s": 1, "sec": 1, "second": 1, "seconds": 1,
            "m": 60, "min": 60, "minute": 60, "minutes": 60,
            "h": 3600, "hr": 3600, "hour": 3600, "hours": 3600,
            "d": 86400, "day": 86400, "days": 86400,
            "w": 604800, "week": 604800, "weeks": 604800,
            "y": 31536000, "year": 31536000, "years": 31536000
        ]

        guard let fromFactor = toSeconds[from] else { return nil }

        let seconds = value * fromFactor

        if let target = to, !target.isEmpty, let toFactor = toSeconds[target] {
            return formatResult(seconds / toFactor, unit: target)
        }

        // Format as hours:minutes:seconds for reasonable values
        if seconds < 86400 {
            let hours = Int(seconds) / 3600
            let mins = (Int(seconds) % 3600) / 60
            let secs = Int(seconds) % 60
            return String(format: "%02d:%02d:%02d", hours, mins, secs)
        }

        let days = seconds / 86400
        return formatResult(days, unit: "days")
    }

    private func formatResult(_ value: Double, unit: String) -> String {
        if value == floor(value) && value < 1000000 {
            return String(format: "%.0f %@", value, unit)
        } else if value < 0.01 {
            return String(format: "%.4f %@", value, unit)
        } else if value < 1 {
            return String(format: "%.3f %@", value, unit)
        } else if value < 100 {
            return String(format: "%.2f %@", value, unit)
        } else {
            return String(format: "%.1f %@", value, unit)
        }
    }

    func focusTextField() {
        window?.makeFirstResponder(inputField)
    }

    func reset() {
        inputField.stringValue = ""
        resultLabel.stringValue = ""
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onEscape?()
            return true
        }
        return false
    }
}
