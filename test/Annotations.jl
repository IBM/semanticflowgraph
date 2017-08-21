module TestAnnotations
using Base.Test

using Catlab
using OpenDiscCore

pres = Presentation(String)
A, B, C, D = Ob(Monocl, "A", "B", "C", "D")
f = Hom("f", A, B)
g = Hom("g", B, C)
h = Hom("h", D, D)
add_generators!(pres, [A, B, C, D, f, g])

note = annotation_from_json(Dict(
  "schema" => "annotation",
  "language" => "python",
  "package" => "mypkg",
  "id" => "a",
  "class" => "ClassA",
  "definition" => "A"
), pres)
@test note.name == AnnotationID("python", "mypkg", "a")
@test note.language == Dict(:class => "ClassA")
@test note.definition == A

note = annotation_from_json(Dict(
  "schema" => "annotation",
  "language" => "python",
  "package" => "mypkg",
  "id" => "a-do-composition",
  "class" => "ClassA",
  "method" => "do_composition",
  "definition" => [
    "otimes",
    ["compose", "f", "g" ],
    ["Hom", "h", "D", "D" ],
  ]
), pres)
@test note.name == AnnotationID("python", "mypkg", "a-do-composition")
@test note.language == Dict(:class => "ClassA", :method => "do_composition")
@test note.definition == otimes(compose(f, g), h)

end
