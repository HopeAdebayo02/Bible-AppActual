import SwiftUI

struct ValidationReportView: View {
    @State private var issues: [ChapterValidationIssue] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading { ProgressView() }
            ForEach(issues) { issue in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(issue.bookName) \(issue.chapter)").font(.headline)
                        if let v = issue.version, v.isEmpty == false {
                            Text(v).font(.caption).foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                    Text(issue.problem).font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Validation Report")
        .task { await runValidationAllVersions() }
    }

    private func runValidationAllVersions() async {
        await MainActor.run {
            isLoading = true
        }
        let validationIssues = await ValidationService.shared.validateAllVersions()
        await MainActor.run {
            issues = validationIssues
            isLoading = false
        }
    }
}


