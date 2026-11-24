import Testing

/// Parent suite for every test that opens real windows. They share one NSApplication and
/// one key window, so they must never run concurrently (a second window steals key status).
@MainActor
@Suite(.serialized)
enum ShellTests {}
