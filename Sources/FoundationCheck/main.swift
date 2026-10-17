import Foundation

// Prints ICU-backed Foundation results. The output must match expected/foundation.txt on every architecture.
let date = Date(timeIntervalSince1970: 1_800_000_000)
let utc = TimeZone(identifier: "UTC")!
for id in ["en_US", "de_DE", "fr_FR", "ru_RU", "ja_JP", "ar_EG", "tr_TR"] {
    let locale = Locale(identifier: id)
    print("date \(id) \(date.formatted(Date.FormatStyle(date: .complete, time: .shortened, locale: locale, timeZone: utc)))")
    print("number \(id) \(1234567.891.formatted(.number.locale(locale))) | \(99.5.formatted(.currency(code: "EUR").locale(locale)))")
    print("duration \(id) \(Duration.seconds(3725).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(locale)))")
    var capitalized = Date.FormatStyle(date: .complete, time: .omitted, locale: locale, timeZone: utc)
    capitalized.capitalizationContext = .beginningOfSentence
    print("capitalized \(id) \(date.formatted(capitalized)) | \("istanbul ijssel".capitalized(with: locale))")
    print("relative \(id) \(date.formatted(Date.RelativeFormatStyle(presentation: .named, capitalizationContext: .beginningOfSentence).locale(locale)))")
}
for encoding: String.Encoding in [.shiftJIS, .japaneseEUC, .windowsCP1251, .isoLatin2, .macOSRoman] {
    let data = "Привет 日本 Žluť".data(using: encoding, allowLossyConversion: true)
    print("encoding \(encoding.rawValue) \(data?.count ?? -1) bytes")
}
print("transform \("Привет, мир".applyingTransform(.toLatin, reverse: false) ?? "nil")")
let regex = try NSRegularExpression(pattern: "\\b\\w+?\\b", options: .useUnicodeWordBoundaries)
print("regex \(regex.numberOfMatches(in: "我们是中国人 hello", range: NSRange(location: 0, length: 12))) matches")
