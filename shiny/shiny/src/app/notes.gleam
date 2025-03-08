import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Note {
  Note(
    id: String,
    title: String,
    content: String,
    tags: List(String),
    created: String,
    modified: String,
    is_pinned: Bool,
    color: Option(String),
  )
}

pub fn to_json(note: Note) -> Json {
  json.object([
    #("id", json.string(note.id)),
    #("title", json.string(note.title)),
    #("content", json.string(note.content)),
    #("tags", json.array(note.tags, of: json.string)),
    #("created", json.string(note.created)),
    #("modified", json.string(note.modified)),
    #("is_pinned", json.bool(note.is_pinned)),
    #("color", case note.color {
      Some(c) -> json.string(c)
      None -> json.null()
    }),
  ])
}

pub fn from_json(json: Json) -> Result(Note, String) {
  use id <- json.decode_field(json, "id", json.string)
  use title <- json.decode_field(json, "title", json.string)
  use content <- json.decode_field(json, "content", json.string)
  use tags <- json.decode_field(json, "tags", json.array(json.string))
  use created <- json.decode_field(json, "created", json.string)
  use modified <- json.decode_field(json, "modified", json.string)
  use is_pinned <- json.decode_field(json, "is_pinned", json.bool)
  use color <- json.decode_field(json, "color", json.nullable(json.string))

  Ok(Note(
    id: id,
    title: title,
    content: content,
    tags: tags,
    created: created,
    modified: modified,
    is_pinned: is_pinned,
    color: color,
  ))
}
