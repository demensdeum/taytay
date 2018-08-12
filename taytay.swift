import Foundation

let argumentExample = "[\\\"/home/demensdeum/Sources/gitreposity1\\\",\\ \\\"/home/demensdeum/Sources/gitreposity2\\\"]"

fileprivate func directoryExistsAtPath(_ path: String) -> Bool {
    var isDirectory = ObjCBool(true)
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
}

final class Shell
{
    func outputOf(commandName: String, arguments: [String] = []) -> String? {
        return bash(commandName: commandName, arguments:arguments)
    }
    
    private func bash(commandName: String, arguments: [String]) -> String? {
        guard var whichPathForCommand = executeShell(command: "/bin/bash" , arguments:[ "-l", "-c", "which \(commandName)" ]) else {
            return "\(commandName) not found"
        }
        whichPathForCommand = whichPathForCommand.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        return executeShell(command: whichPathForCommand, arguments: arguments)
    }
    
    private func executeShell(command: String, arguments: [String] = []) -> String? {
        let task = Process()
        task.executableURL = URL(string: command)
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe

	do {
	        try task.run()
	} catch {
		print("Process run error: \(error)")
	}
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String? = String(data: data, encoding: String.Encoding.utf8)
        
        return output
    }

}

final class RepositoryController {

	enum RepositoryControllerResult {
		case nothingToCommit
		case somethingToCommit
		case somethingToPush
	}

	private var path: String

	init(path: String) {
		guard directoryExistsAtPath(path) == true else {
			print("End game. Path does not exists: \(path)")
			exit(5)
		}
		self.path = path
	}

	func checkStatus() -> RepositoryControllerResult {
		FileManager.default.changeCurrentDirectoryPath(path)
		guard let result = Shell().outputOf(commandName: "git", arguments: ["status","."]) else { 
			print("No output from git command, for path: \(path)")
			exit(2) 
		}
		
		if result.contains("Your branch is ahead of") {
			return RepositoryControllerResult.somethingToPush
		}
		else if result.contains("nothing to commit") {
			return RepositoryControllerResult.nothingToCommit
		}
		else {
			return RepositoryControllerResult.somethingToCommit
		}
	}

	func handle(result: RepositoryControllerResult) {
		switch result {
			case .nothingToCommit:
				print("Nothing to commit at path: \(path)")

			case .somethingToCommit:
				print("Something to commit at path: \(path)")
				runSourceControlTool()
				
			case .somethingToPush:
				print("Something to push at path: \(path)")
				runSourceControlTool()
		}
	}

	private func runSourceControlTool() {
		guard let _ = Shell().outputOf(commandName: "sh", arguments: ["-c","git-cola", path]) else { 
			print("No output from git-cola command, for path: \(path); git-cola not installed?")
			exit(4) 
		}
	}
}

print("Welcome to TayTay v1.1 - fast, simple source control tool.")

if CommandLine.arguments.count != 2 {
	print("Wrong arguments! Shake It Off! You should call taytay that way: taytay \(argumentExample)\nYour arguments:\(CommandLine.arguments[1])")
	exit(1)
}

let repositoriesString = CommandLine.arguments[1]
let data = repositoriesString.data(using: .utf8)!

var repositories = [String]()
do {
	repositories = try JSONSerialization.jsonObject(with: data, options: []) as? [String] ?? []
} catch {
	print("JSON parsing error: \(error); I guess it's in wrong format, check \" symbol escapes, space must be escaped also. Here is your argument:\n\(repositoriesString)\nMust be something like:\n\(argumentExample)\nBegin Again")
	exit(6)
}

if (repositories.count < 1) {
	print("No repositories? stop")
	exit(3)
}

for repository in repositories {
	for tries in 1...2 {
		print("Check repository status try \(tries)")
		let repositoryController = RepositoryController(path: repository)
		let result = repositoryController.checkStatus()
		repositoryController.handle(result: result)
	}
}

print("Bye-Bye!")

exit(0)
