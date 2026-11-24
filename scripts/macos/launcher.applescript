-- Wrapper app for the Uno desktop build of NuGet Package Explorer on macOS.
--
-- Finder opens documents by sending an "open documents" Apple Event, which the Uno macOS host
-- does not forward to the app. This applet receives that event and starts the real app
-- (bundled in Contents/Resources) with the file path as a command-line argument instead.

on run
	do shell script "open " & quoted form of innerApp()
end run

on open theFiles
	repeat with theFile in theFiles
		do shell script "open -n " & quoted form of innerApp() & " --args " & quoted form of (POSIX path of theFile)
	end repeat
end open

on innerApp()
	return (POSIX path of (path to me)) & "Contents/Resources/NuGet Package Explorer.app"
end innerApp
