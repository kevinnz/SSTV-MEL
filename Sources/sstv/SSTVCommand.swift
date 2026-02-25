import ArgumentParser

@main
struct SSTVCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sstv",
        abstract: "Decode SSTV (Slow-Scan Television) audio signals into images.",
        discussion: """
        SSTV-MEL decodes WAV files containing SSTV transmissions into PNG or \
        JPEG images. Supports PD120, PD180, and Robot36 modes with automatic \
        VIS code detection.

        For machine-readable output, use --json on any subcommand.
        """,
        version: "0.7.0",
        subcommands: [Decode.self, Info.self],
        defaultSubcommand: Decode.self
    )
}
