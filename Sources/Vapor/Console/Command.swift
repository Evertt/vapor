import VaporConsoleOutput

/** Console command protocol */
public protocol Command {
    ///Console this command is registered to
    var console: Console { get }

    ///Name of the command
    var name: String { get }

    ///Optional help info for the command
    var help: String? { get }

    ///Arguments for this command
    var arguments: [InputArgument] { get }

    ///Options for this command
    var options: [InputOption] { get }

    /**
        Initialize the command
        - parameter console: Console instance this command will be registered on
    */
    init(console: Console)

    /**
        Called by `run()` after input has been compiled
        - parameter input: CLI input
        - throws: Console.Error
    */
    func handle(input: Input) throws

}

extension Command {

    ///Convenience accessor for the console’s app
    public var app: Application {
        return console.app
    }

    ///Convenience accessor for the console’s app
    public var output: Output {
        return console.output
    }

    ///Arguments for this command
    public var arguments: [InputArgument] {
        return []
    }

    ///Options for this command
    public var options: [InputOption] {
        return []
    }

    ///Optional help info for the command
    public var help: String? {
        return nil
    }

    ///Default options every command has
    internal var defaultOptions: [InputOption] {
        return [
            // Triggers HelpCommand
            InputOption("help", mode: .None, help: "Display this help message"),

            // Application reads/applies these values
            InputOption("env", mode: .Optional, help: "Specify an environment to run in."),
            InputOption("workDir", mode: .Optional, help: "Change the work directory.", value: "./")
        ]
    }

    /**
        Run the command
        - parameter rawInput: Raw Input instance generated from Process.arguments
        - throws: Console.Error
    */
    public func run(rawInput: Input) throws {
        try handle(Input(
            arguments: try self.compile(arguments: rawInput.arguments),
            options: try self.compile(options: rawInput.options)
        ))
    }

    private func compile(arguments rawArguments: [InputArgument]) throws -> [InputArgument] {
        let arguments = self.arguments
        var compiledArguments = [String: InputArgument]()

        // Ensure the input arguments doesn’t exceed the
        // number of defined arguments
        if rawArguments.count - 1 > arguments.count {
            throw Console.Error.TooManyArguments
        }

        // Iterate through input arguments and match them to
        // to the defined arguments
        for (index, argument) in rawArguments.enumerated() {
            if index == 0 {
                // Skip first argument as it’s the command name
                continue
            }

            let name = arguments[index - 1].name
            compiledArguments[name] = InputArgument(
                name,
                mode: argument.mode,
                value: argument.value
            )
        }

        // If the input argument count isn’t the same as the
        // defined argument count, iterate through and make sure
        // all the required arguments are satisfied
        if compiledArguments.count != arguments.count {
            for argument in arguments {
                guard argument.mode == .Required else {
                    continue
                }

                if compiledArguments[argument.name] == nil {
                    throw Console.Error.MissingArgument(argument: argument.name)
                }
            }
        }

        return Array(compiledArguments.values)
    }

    private func compile(options rawOptions: [InputOption]) throws -> [InputOption] {
        var options = [String: InputOption]()

        for option in self.options + defaultOptions {
            options[option.name] = option
        }

        var compiledOptions = [String: InputOption]()

        // Iterate through input options and match them to
        // the defined options
        for option in rawOptions {
            guard let definedOption = options[option.name] else {
                throw Console.Error.InvalidOption(option: option.name)
            }

            if definedOption.mode == .None && option.value != nil {
                throw Console.Error.InvalidOptionValue(option: option.name)
            }

            compiledOptions[option.name] = option
        }

        // If the input options count isn’t the same as the
        // defined option count, iterate through and make sure
        // all the required options are satisfied
        if compiledOptions.count != options.count {
            for (_, option) in options {
                guard option.mode != .None && compiledOptions[option.name] == nil else {
                    continue
                }

                if option.mode == .Required {
                    throw Console.Error.MissingOption(option: option.name)
                } else {
                    compiledOptions[option.name] = option
                }
            }
        }

        return Array(compiledOptions.values)
    }

    /**
        Write a message without any formatting
        - parameter message: Message to write
    */
    public func line(message: String) {
        output.write(message)
    }

    /**
        Write an info message
        - parameter message: Info message to write
    */
    public func info(message: String) {
        output.write("<info>\(message)</info>")
    }

    /**
        Write a comment message
        - parameter message: Comment message to write
    */
    public func comment(message: String) {
        output.write("<comment>\(message)</comment>")
    }

    /**
        Write an error message
        - parameter message: Error message to write
    */
    public func error(message: String) {
        output.write("<error>\(message)</error>")
    }

}