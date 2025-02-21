module editor;

import vibe.d;
import common.note;
import common.vault;

// API handlers for editor functionality
void getNote(HTTPServerRequest req, HTTPServerResponse res) {
    auto id = req.params["id"];
    auto vaultManager = new VaultManager();
    
    if (auto note = vaultManager.getNote(id)) {
        res.writeJsonBody(*note);
    } else {
        res.statusCode = HTTPStatus.notFound;
        res.writeJsonBody(["error": "Note not found"]);
    }
}

void updateNote(HTTPServerRequest req, HTTPServerResponse res) {
    auto id = req.params["id"];
    auto vaultManager = new VaultManager();
    
    auto json = req.json;
    if (auto note = vaultManager.getNote(id)) {
        note.title = json["title"].get!string;
        note.content = json["content"].get!string;
        note.tags = json["tags"].deserializeJson!(string[]);
        
        vaultManager.addNote(*note);  // Save changes
        res.writeJsonBody(*note);
    } else {
        res.statusCode = HTTPStatus.notFound;
        res.writeJsonBody(["error": "Note not found"]);
    }
}

void createNote(HTTPServerRequest req, HTTPServerResponse res) {
    auto json = req.json;
    auto note = Note(
        json["title"].get!string,
        json["content"].get!string
    );
    note.tags = json["tags"].deserializeJson!(string[]);
    
    auto vaultManager = new VaultManager();
    vaultManager.addNote(note);
    
    res.writeJsonBody(note);
} 

 