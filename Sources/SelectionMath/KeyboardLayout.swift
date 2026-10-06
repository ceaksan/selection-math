import Carbon

enum KeyboardLayout {
    static func current() -> TISInputSource? {
        if let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(), layoutData(source) != nil {
            return source
        }
        return TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
    }

    static func installed(id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        return (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource])?.first
    }

    static func installedLayoutIDs() -> [String] {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
        return sources.compactMap { source in
            TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
                .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
        }
    }

    static func character(keyCode: UInt16, carbonModifiers: UInt32, layout: TISInputSource) -> String? {
        guard let data = layoutData(layout) else { return nil }
        return data.withUnsafeBytes { raw -> String? in
            guard let keyboard = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(keyboard, keyCode, UInt16(kUCKeyActionDown), (carbonModifiers >> 8) & 0xFF,
                                        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                        &deadKeys, characters.count, &length, &characters)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: length)
        }
    }

    static func keyCode(for character: String, carbonModifiers: UInt32, layout: TISInputSource) -> UInt16? {
        (0..<128).map(UInt16.init).first {
            self.character(keyCode: $0, carbonModifiers: carbonModifiers, layout: layout)?.lowercased() == character
        }
    }

    private static func layoutData(_ source: TISInputSource) -> Data? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        return Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
    }
}
