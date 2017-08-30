module TestConceptJSON
using Base.Test

using Catlab
using OpenDiscCore

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

end
