import lustre
import lustre/attribute.{class}
import lustre/element.{div, text}

pub type Model =
  Nil

pub type Msg {
  NoOp
}

pub fn init() -> #(Model, lustre.Command(Msg)) {
  #(Nil, lustre.none())
}

pub fn update(msg: Msg, model: Model) -> #(Model, lustre.Command(Msg)) {
  case msg {
    NoOp -> #(model, lustre.none())
  }
}

pub fn view(model: Model) -> element.Element(Msg) {
  div([class("app-container")], [
    div([class("sidebar")], [text("Notes List")]),
    div([class("main-content")], [text("Note Editor")]),
  ])
}
