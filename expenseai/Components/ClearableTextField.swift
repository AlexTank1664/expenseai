import SwiftUI

// Мы сделали компонент универсальным (generic) по типу заголовка S,
// где S - это любой тип строки (String, Substring, и т.д.)
struct ClearableTextField<S: StringProtocol, Format: ParseableFormatStyle>: View where Format.FormatInput == Double, Format.FormatOutput == String {

    // --- Публичный интерфейс ---
    private let title: S // Теперь это универсальный тип строки
    @Binding private var value: Double
    private let format: Format

    // --- Внутреннее состояние ---
    @State private var internalValue: Double?
    @FocusState private var isFocused: Bool
    
    // Добавляем публичный инициализатор, чтобы вызов был красивым
    init(_ title: S, value: Binding<Double>, format: Format) {
        self.title = title
        self._value = value // _value для доступа к самому Binding
        self.format = format
    }

    var body: some View {
        TextField(
            title, // Используем наш title
            value: $internalValue,
            format: format
        )
        .focused($isFocused)
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
        // Логика очистки/возврата нуля при смене фокуса
        .onChange(of: isFocused) {
            if isFocused {
                if internalValue == 0 {
                    internalValue = nil
                }
            } else {
                if internalValue == nil {
                    internalValue = 0
                }
            }
        }
        // Синхронизация внешнего значения с внутренним
        .onChange(of: internalValue) {
            value = internalValue ?? 0.0
        }
        // Инициализация и синхронизация при изменениях извне
        .onAppear {
            internalValue = value
        }
        .onChange(of: value) {
            if !isFocused {
                internalValue = value
            }
        }
    }
}

