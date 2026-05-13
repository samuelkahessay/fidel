import Foundation

enum AudioContentType: String, Codable, Hashable {
    case phrase
    case vocabulary
    case conversationLine
    case fidelCharacter
}

struct AudioContentKey: Hashable {
    let contentType: AudioContentType
    let contentId: String
}

struct AudioAsset: Identifiable, Codable, Hashable {
    let id: String
    let contentType: AudioContentType
    let contentId: String
    let language: String
    let provider: String
    let voice: String
    let format: String
    let file: String
    let text: String
    let sourceTextHash: String

    var contentKey: AudioContentKey {
        AudioContentKey(contentType: contentType, contentId: contentId)
    }
}
