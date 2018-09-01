# Copyright 2018 IBM Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module TestOntologyJSON
using Test

using Catlab
using SemanticFlowGraphs

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
    "is-a" => "A",
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
