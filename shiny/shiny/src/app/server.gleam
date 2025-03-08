import gleam/bit_string
import gleam/http.{Get, Post, Put}
import gleam/http/response.{type Response}
import gleam/json
import gleam/string
import mist.{type Connection, type ResponseData}
import app/notes.{type Note}

pub fn start() {
  let router = fn(req) {
    case req.method, string.split(req.path, on: "/") {
      // API routes
      Get, ["api", "notes"] -> handle_get_notes(req)
      Get, ["api", "notes", id] -> handle_get_note(req, id)
      Post, ["api", "notes"] -> handle_create_note(req)
      Put, ["api", "notes", id] -> handle_update_note(req, id)
      
      // Static file serving
      Get, [] -> serve_file("index.html")
      Get, ["assets", ..path] -> serve_static(path)
      
      // SPA fallback
      Get, _ -> serve_file("index.html")
      
      _, _ -> not_found()
    }
  }

  let assert Ok(_) = 
    mist.new()
    |> mist.port(3000)
    |> mist.router(router)
    |> mist.start()
}

fn handle_get_notes(_req: mist.Request) -> Response(ResponseData) {
  // TODO: Implement notes fetching
  json_response([])
}

fn handle_get_note(_req: mist.Request, id: String) -> Response(ResponseData) {
  // TODO: Implement single note fetching
  not_found()
}

fn handle_create_note(req: mist.Request) -> Response(ResponseData) {
  // TODO: Implement note creation
  not_found()
}

fn handle_update_note(req: mist.Request, id: String) -> Response(ResponseData) {
  // TODO: Implement note updating
  not_found()
}

fn serve_file(path: String) -> Response(ResponseData) {
  case read_priv_file(path) {
    Ok(content) -> {
      response.new(200)
      |> response.set_header("content-type", content_type(path))
      |> response.set_body(bit_string.from_string(content))
    }
    Error(_) -> not_found()
  }
}

fn serve_static(path: List(String)) -> Response(ResponseData) {
  let path = string.join(path, with: "/")
  serve_file(string.concat(["assets/", path]))
}

fn json_response(data: List(Note)) -> Response(ResponseData) {
  let json = json.array(data, of: notes.to_json)
  
  response.new(200)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(json.to_string(json))
}

fn not_found() -> Response(ResponseData) {
  response.new(404)
  |> response.set_body("Not Found")
}

fn content_type(path: String) -> String {
  case string.lowercase(path) {
    case p if string.ends_with(p, ".html") -> "text/html"
    case p if string.ends_with(p, ".js") -> "application/javascript"
    case p if string.ends_with(p, ".css") -> "text/css"
    case p if string.ends_with(p, ".json") -> "application/json"
    case p if string.ends_with(p, ".png") -> "image/png"
    case p if string.ends_with(p, ".jpg") -> "image/jpeg"
    case p if string.ends_with(p, ".svg") -> "image/svg+xml"
    _ -> "application/octet-stream"
  }
}

fn read_priv_file(path: String) -> Result(String, Nil) {
  // TODO: Implement file reading from priv directory
  Error(Nil)
} 