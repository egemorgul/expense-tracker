import Foundation
import WidgetKit

extension WidgetSnapshot {
    init(_ balances: Balances) {
        self.init(amounts: Dictionary(uniqueKeysWithValues: BalanceAccount.allCases.map { ($0, balances[$0]) }))
    }

    /// UI tests run on made-up data, which must not reach the widgets.
    func publish() {
        guard !ProcessInfo.processInfo.arguments.contains("-uiTesting"), self != Self.load() else { return }
        save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
