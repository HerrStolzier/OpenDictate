import IOKit
import IOKit.hid
import OpenDictateCore

/// Reads the connected keyboards from the I/O Registry. This only reads
/// device properties; it opens no device and needs no permission.
enum KeyboardInventory {
    static func connectedKeyboards() -> [KeyboardDevice] {
        guard let matching = IOServiceMatching(kIOHIDDeviceKey) else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var keyboards: [KeyboardDevice] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            // A composite device may offer its keyboard collection next to a
            // different primary usage, so check every usage pair; the primary
            // usage covers devices that publish no pairs.
            let usages =
                (property(kIOHIDDeviceUsagePairsKey) as? [[String: Any]] ?? []).map {
                    ($0[kIOHIDDeviceUsagePageKey] as? Int, $0[kIOHIDDeviceUsageKey] as? Int)
                } + [(property(kIOHIDPrimaryUsagePageKey) as? Int, property(kIOHIDPrimaryUsageKey) as? Int)]
            guard usages.contains(where: { $0 == kHIDPage_GenericDesktop && $1 == kHIDUsage_GD_Keyboard })
            else { continue }
            keyboards.append(
                KeyboardDevice(
                    vendorID: property(kIOHIDVendorIDKey) as? Int ?? 0,
                    productID: property(kIOHIDProductIDKey) as? Int ?? 0,
                    isBuiltIn: property(kIOHIDBuiltInKey) as? Bool ?? false))
        }
        return keyboards
    }
}
