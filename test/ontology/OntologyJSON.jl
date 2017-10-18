module TestOntologyJSON
using Base.Test

using Catlab
using OpenDiscCore

# Concepts
##########

TestPres = Presentation(String)
A, B, C, A0 = Ob(Monocl, "A", "B", "C", "A0")
I = munit(Monocl.Ob)
add_generators!(TestPres, [A, B, C, A0])
add_generator!(TestPres, SubOb(A0, A))
add_generator!(TestPres, Hom("f", A, B))
add_generator!(TestPres, Hom("g", I, otimes(A,B)))

concept(pairs...) = Dict("schema" => "concept", pairs...)

const docs = [
  concept(
    "kind" => "object",
    "id" => "A",
  ),
  concept(
    "kind" => "object",
    "id" => "B",
  ),
  concept(
    "kind" => "object",
    "id" => "C",
  ),
  concept(
    "kind" => "object",
    "id" => "A0",
    "subconcept" => ["A"],
  ),
  concept(
    "kind" => "morphism",
    "id" => "f",
    "domain" => [
      Dict("object" => "A"),
    ],
    "codomain" => [
      Dict("object" => "B"),
    ]
  ),
  concept(
    "kind" => "morphism",
    "id" => "g",
    "domain" => [],
    "codomain" => [
      Dict("object" => "A"),
      Dict("object" => "B"),
    ]
  )
]

pres = presentation_from_json(docs)
@test generators(pres, Monocl.Ob) == generators(TestPres, Monocl.Ob)
@test generators(pres, Monocl.Hom) == generators(TestPres, Monocl.Hom)
@test generators(pres, Monocl.SubOb) == generators(TestPres, Monocl.SubOb)

# Annotations
#############

pres = Presentation(String)
A, B, C, D = Ob(Monocl, "A", "B", "C", "D")
f = Hom("f", A, B)
g = Hom("g", B, C)
h = Hom("h", D, D)
add_generators!(pres, [A, B, C, D, f, g])

note = annotation_from_json(Dict(
  "schema" => "annotation",
  "kind" => "object",
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
  "kind" => "morphism",
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
