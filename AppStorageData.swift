import SwiftUI

/// @AppStorageのようにData型を扱えるカスタムProperty Wrapper
@propertyWrapper
struct AppStorageData: DynamicProperty {
    private let key: String
    private let defaultValue: Data?
    
    @State private var value: Data?
    
    init(wrappedValue: Data?, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        self._value = State(initialValue: UserDefaults.standard.data(forKey: key) ?? wrappedValue)
    }
    
    init(_ key: String) {
        self.init(wrappedValue: nil, key)
    }
    
    var wrappedValue: Data? {
        get {
            value
        }
        nonmutating set {
            // Update both the State and UserDefaults
            _value.wrappedValue = newValue
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
            // 変更を即座に通知
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
        }
    }
    
    var projectedValue: Binding<Data?> {
        Binding(
            get: { value },
            set: { newValue in
                // Update both the State and UserDefaults
                _value.wrappedValue = newValue
                if let newValue = newValue {
                    UserDefaults.standard.set(newValue, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
                // 変更を即座に通知
                NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
            }
        )
    }
}

