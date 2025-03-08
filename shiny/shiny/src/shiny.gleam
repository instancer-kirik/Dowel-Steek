import app/components/app.{App}
import app/server
import gleam/io
import lustre
import lustre/element.{text}

pub fn main() {
  // Start the HTTP server
  server.start()
  io.println("Server running at http://localhost:3000")

  // Mount our Lustre app to the DOM
  case lustre.start(App, Nil, selector: "#app") {
    Ok(_) -> io.println("App started!")
    Error(error) -> io.debug(error)
  }
}
