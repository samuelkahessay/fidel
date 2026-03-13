import Foundation

@MainActor
@Observable
final class AppViewModel {
    var isLoading = false
    var errorMessage: String?

    private let lessonRepository: LessonRepositoryProtocol

    init(lessonRepository: LessonRepositoryProtocol = LessonRepository.shared) {
        self.lessonRepository = lessonRepository
    }

    func loadData() {
        isLoading = true
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            self.isLoading = false
        }
    }
}
