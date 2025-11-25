import Cocoa

class NotesManager {
    static let shared = NotesManager()

    private var notes: [Note] = []
    private let defaults = UserDefaults.standard
    private let notesKey = "com.telescope.notes"

    private init() {
        loadNotes()
    }

    // MARK: - CRUD Operations

    func createNote(title: String, content: String) -> Note {
        let note = Note(
            id: UUID().uuidString,
            title: title,
            content: content,
            timestamp: Date(),
            lastModified: Date()
        )
        notes.insert(note, at: 0)
        saveNotes()
        return note
    }

    func getNotes() -> [Note] {
        return notes
    }

    func getNote(id: String) -> Note? {
        return notes.first { $0.id == id }
    }

    func updateNote(id: String, title: String?, content: String?) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }

        var note = notes[index]
        if let title = title {
            note.title = title
        }
        if let content = content {
            note.content = content
        }
        note.lastModified = Date()

        notes[index] = note
        saveNotes()
    }

    func deleteNote(id: String) {
        notes.removeAll { $0.id == id }
        saveNotes()
    }

    func deleteAllNotes() {
        notes.removeAll()
        saveNotes()
    }

    // MARK: - Persistence

    private func saveNotes() {
        let encoded = notes.map { note -> [String: Any] in
            [
                "id": note.id,
                "title": note.title,
                "content": note.content,
                "timestamp": note.timestamp.timeIntervalSince1970,
                "lastModified": note.lastModified.timeIntervalSince1970
            ]
        }
        defaults.set(encoded, forKey: notesKey)
    }

    private func loadNotes() {
        guard let encoded = defaults.array(forKey: notesKey) as? [[String: Any]] else { return }

        notes = encoded.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let content = dict["content"] as? String,
                  let timestamp = dict["timestamp"] as? TimeInterval,
                  let lastModified = dict["lastModified"] as? TimeInterval else {
                return nil
            }
            return Note(
                id: id,
                title: title,
                content: content,
                timestamp: Date(timeIntervalSince1970: timestamp),
                lastModified: Date(timeIntervalSince1970: lastModified)
            )
        }
    }
}

struct Note {
    let id: String
    var title: String
    var content: String
    let timestamp: Date
    var lastModified: Date

    var preview: String {
        // Show first line of content or first 60 chars
        let lines = content.split(separator: "\n", maxSplits: 1)
        let firstLine = lines.first.map(String.init) ?? content
        let maxLength = 60

        if firstLine.count > maxLength {
            let endIndex = firstLine.index(firstLine.startIndex, offsetBy: maxLength)
            return String(firstLine[..<endIndex]) + "..."
        }
        return firstLine
    }

    var isEmpty: Bool {
        return title.isEmpty && content.isEmpty
    }
}
