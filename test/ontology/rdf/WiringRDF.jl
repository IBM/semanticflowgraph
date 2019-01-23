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

module TestWiringRDF
using Test

using Serd, Serd.RDF
using Catlab, Catlab.Doctrines, Catlab.WiringDiagrams

using SemanticFlowGraphs

const R = Resource

A, B, C, D = Ob(FreeSymmetricMonoidalCategory, :A, :B, :C, :D)
f = Hom(:f, A, B)
g = Hom(:g, B, C)
h = Hom(:h, D, D)
diagram = to_wiring_diagram(otimes(compose(f,g), h))
_, stmts = wiring_diagram_to_rdf(diagram)
#write_rdf(stdout, stmts)

vs = box_ids(diagram)
vin, vout = input_id(diagram), output_id(diagram)
find_vertex = value -> vs[findfirst(v -> box(diagram, v).value == value, vs)]
fv, gv, hv = find_vertex(:f), find_vertex(:g), find_vertex(:h)

# Check RDF type of boxes and ports.
@test Triple(Blank("n$fv"), R("rdf","type"), R("monocl","Box")) in stmts
@test Triple(Blank("n$fv:in1"), R("rdf","type"), R("monocl","Port")) in stmts
@test Triple(Blank("n$fv:out1"), R("rdf","type"), R("monocl","Port")) in stmts

# Check values of boxes and ports.
@test Triple(Blank("n$fv"), R("monocl","value"), Literal("f")) in stmts
@test Triple(Blank("n$fv:in1"), R("monocl","value"), Literal("A")) in stmts
@test Triple(Blank("n$fv:out1"), R("monocl","value"), Literal("B")) in stmts

# Check wires, in both reified and non-reified form.
i = first([ i for (i, wire) in enumerate(wires(diagram))
            if wire.source.box == fv && wire.target.box == gv ])
@test Triple(Blank("e$i"), R("rdf","type"), R("monocl","Wire")) in stmts
@test Triple(Blank("e$i"), R("monocl","source"), Blank("n$fv:out1")) in stmts
@test Triple(Blank("e$i"), R("monocl","target"), Blank("n$gv:in1")) in stmts
@test Triple(Blank("n$fv:out1"), R("monocl","wire"), Blank("n$gv:in1")) in stmts

end
