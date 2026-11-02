//
//  DuoFoldIntent.swift
//  PicksyWidget
//
//  "Record Duo fold" — the action a Shortcuts automation runs each time the
//  iPhone Duo folds or unfolds.
//
//  Lives in the widget EXTENSION on purpose: an intent defined in the app target
//  needs iOS to launch Picksy itself, which it does not do when the app was
//  closed (the count silently never happened). An extension is started by the
//  system on demand, so counting works with Picksy fully closed. Shares
//  DuoFold.swift / DuoFoldStore.swift with the app through the App Group.
//

import AppIntents

enum DuoFoldEventOption: String, AppEnum {
    case any
    case opened
    case closed

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Duo movement" }
    static var caseDisplayRepresentations: [DuoFoldEventOption: DisplayRepresentation] {
        [
            .any: "Opened or closed",
            .opened: "Opened",
            .closed: "Closed",
        ]
    }

    var kind: DuoFoldKind {
        switch self {
        case .any: return .any
        case .opened: return .opened
        case .closed: return .closed
        }
    }
}

struct RecordDuoFoldIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Duo fold"
    static var description = IntentDescription(
        "Counts one fold or unfold of your iPhone Duo in Picksy. Run it from a Shortcuts automation so Picksy can count even when it is closed."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Movement", default: .any)
    var event: DuoFoldEventOption

    static var parameterSummary: some ParameterSummary {
        Summary("Record Duo \(\.$event)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let data = DuoFoldStore.record(event.kind)
        return .result(value: data.total)
    }
}
