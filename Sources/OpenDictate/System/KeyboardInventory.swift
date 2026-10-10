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
            guard property(kIOHIDPrimaryUsagePageKey) as? Int == kHIDPage_GenericDesktop,
                property(kIOHIDPrimaryUsageKey) as? Int == kHIDUsage_GD_Keyboard
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
