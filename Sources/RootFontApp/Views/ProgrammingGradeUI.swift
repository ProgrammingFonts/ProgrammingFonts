import SwiftUI

enum ProgrammingGradeUI {
    static func shortText(for grade: ProgrammingGrade) -> String {
        switch grade {
        case .s: return "S"
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .notRecommended: return "NR"
        }
    }

    static func color(for grade: ProgrammingGrade) -> Color {
        switch grade {
        case .s: return .green
        case .a: return .mint
        case .b: return .yellow
        case .c: return .orange
        case .notRecommended: return .red
        }
    }

    static func l10nKey(for grade: ProgrammingGrade) -> L10nKey {
        switch grade {
        case .s: return .gradeS
        case .a: return .gradeA
        case .b: return .gradeB
        case .c: return .gradeC
        case .notRecommended: return .gradeNotRecommended
        }
    }
}
