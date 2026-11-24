import Foundation
import Testing
@testable import PastuCore

@Suite struct ColorValueTests {
    private func rgb(_ text: String) -> (Int, Int, Int, Double)? {
        guard let color = ColorValue(text) else { return nil }
        return (color.red, color.green, color.blue, color.alpha)
    }

    // MARK: Hex

    @Test func sixDigitHex() {
        let c = rgb("#1e90ff")
        #expect(c?.0 == 30 && c?.1 == 144 && c?.2 == 255 && c?.3 == 1)
    }

    @Test func threeDigitHexDoublesEachDigit() {
        let c = rgb("#f80")
        #expect(c?.0 == 255 && c?.1 == 136 && c?.2 == 0)
    }

    @Test func eightAndFourDigitHexCarryAlpha() throws {
        let eight = try #require(rgb("#1E90FF80"))
        #expect(eight.0 == 30 && eight.1 == 144 && eight.2 == 255)
        #expect(abs(eight.3 - 128.0 / 255.0) < 0.001)
        let four = try #require(rgb("#f808"))
        #expect(four.0 == 255 && four.1 == 136 && four.2 == 0)
        #expect(abs(four.3 - 136.0 / 255.0) < 0.001)
    }

    @Test func hexIsCaseInsensitiveAndTrimmed() {
        #expect(rgb("  #AbCdEf \n") != nil)
    }

    @Test(arguments: ["1e90ff", "#12", "#12345", "#1234567", "#123456789", "#ggg", "#12 34 56", "##123456", "", "#"])
    func notHex(text: String) {
        #expect(ColorValue(text) == nil)
    }

    // MARK: rgb()

    @Test func commaSeparatedRGB() {
        let c = rgb("rgb(30, 144, 255)")
        #expect(c?.0 == 30 && c?.1 == 144 && c?.2 == 255 && c?.3 == 1)
    }

    @Test func rgbaWithAlpha() {
        let c = rgb("rgba(30,144,255,0.5)")
        #expect(c?.0 == 30 && c?.3 == 0.5)
    }

    @Test func modernSpaceSeparatedSyntax() {
        let c = rgb("rgb(30 144 255 / 50%)")
        #expect(c?.0 == 30 && c?.1 == 144 && c?.2 == 255 && c?.3 == 0.5)
    }

    @Test func percentagesForChannels() {
        let c = rgb("rgb(100%, 0%, 50%)")
        #expect(c?.0 == 255 && c?.1 == 0 && c?.2 == 128)
    }

    @Test func functionNameIsCaseInsensitive() {
        #expect(rgb("RGB(1, 2, 3)")?.2 == 3)
    }

    @Test(arguments: ["rgb(300, 0, 0)", "rgb(-1, 0, 0)", "rgb(1, 2)", "rgb(1, 2, 3, 4, 5)", "rgb(a, b, c)", "rgb(1, 2, 3", "rgb 1, 2, 3", "rgba(1,2,3,2)", "rgb(1.5, 2, 3)"])
    func notRGB(text: String) {
        #expect(ColorValue(text) == nil)
    }

    // MARK: hsl()

    @Test func hslConvertsToRGB() {
        // hsl(210, 100%, 56%) is dodger blue's neighbour: check a few exact corners instead.
        #expect(rgb("hsl(0, 100%, 50%)")?.0 == 255 && rgb("hsl(0, 100%, 50%)")?.1 == 0)
        #expect(rgb("hsl(120, 100%, 50%)")?.1 == 255 && rgb("hsl(120, 100%, 50%)")?.0 == 0)
        #expect(rgb("hsl(240, 100%, 50%)")?.2 == 255)
        let grey = rgb("hsl(0, 0%, 50%)")
        #expect(grey?.0 == 128 && grey?.1 == 128 && grey?.2 == 128)
    }

    @Test func hslaWithAlpha() {
        #expect(rgb("hsla(0, 100%, 50%, 0.25)")?.3 == 0.25)
    }

    @Test(arguments: ["hsl(0, 100, 50)", "hsl(0, 101%, 50%)", "hsl(abc, 1%, 1%)", "hsl(0, 100%)"])
    func notHSL(text: String) {
        #expect(ColorValue(text) == nil)
    }

    // MARK: Only a colour, nothing else

    @Test(arguments: ["the color #1e90ff is nice", "#1e90ff #ffffff", "color: #1e90ff;", "rgb(1,2,3) and more", "blue", "42"])
    func textAroundAColorIsNotAColor(text: String) {
        #expect(ColorValue(text) == nil)
    }

    @Test func aHugeClipIsNotParsed() {
        #expect(ColorValue(String(repeating: "#", count: 100_000)) == nil)
    }

    // MARK: Display

    @Test func hexString() {
        #expect(ColorValue("rgb(30, 144, 255)")?.hexString == "#1E90FF")
        #expect(ColorValue("#f80")?.hexString == "#FF8800")
        #expect(ColorValue("#1e90ff80")?.hexString == "#1E90FF80")
    }

    @Test func rgbString() {
        #expect(ColorValue("#1e90ff")?.rgbString == "rgb(30, 144, 255)")
        #expect(ColorValue("#1e90ff80")?.rgbString == "rgba(30, 144, 255, 0.5)")
    }

    @Test func descriptionForVoiceOver() {
        #expect(ColorValue("#1e90ff")?.spokenDescription == "Color, red 30, green 144, blue 255")
    }
}
