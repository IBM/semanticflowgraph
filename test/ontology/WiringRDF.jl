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
using Catlab, Catlab.Doctrine, Catlab.Diagram.Wiring

using SemanticFlowGraphs

const R = Resource

A, B, C, D = Ob(FreeSymmetricMonoidalCategory, :A, :B, :C, :D)
f = Hom(:f, A, B)
g = Hom(:g, B, C)
h = Hom(:h, D, D)
diagram = to_wiring_diagram(otimes(compose(f,g), h))
stmts = wiring_diagram_to_rdf(diagram)
#write_rdf(stdout, stmts, syntax="trig")

vs = box_ids(diagram)
vin, vout = input_id(diagram), output_id(diagram)
find_vertex = value -> vs[findfirst(v -> box(diagram, v).value == value, vs)]
fv, gv, hv = find_vertex(:f), find_vertex(:g), find_vertex(:h)

# Check RDF type of boxes and ports.
@test Triple(Blank("box$(fv)"), R("rdf","type"), R("monocl","Box")) in stmts
@test Triple(Blank("box$(fv)_in1"), R("rdf","type"), R("monocl","Port")) in stmts
@test Triple(Blank("box$(fv)_out1"), R("rdf","type"), R("monocl","Port")) in stmts

# Check values of boxes and ports.
@test Triple(Blank("box$(fv)"), R("monocl","value"), Literal("f")) in stmts
@test Triple(Blank("box$(fv)_in1"), R("monocl","value"), Literal("A")) in stmts
@test Triple(Blank("box$(fv)_out1"), R("monocl","value"), Literal("B")) in stmts

# Check special input and output nodes.
@test all(stmt in stmts for stmt in [
  Triple(Blank("box$(vin)_out1"), R("rdf","type"), R("monocl","Port")),
  Triple(Blank("box$(vin)_out2"), R("rdf","type"), R("monocl","Port")),
])
@test all(stmt in stmts for stmt in [
  Triple(Blank("box$(vout)_in1"), R("rdf","type"), R("monocl","Port")),
  Triple(Blank("box$(vout)_in2"), R("rdf","type"), R("monocl","Port")),
])

# Check wires.
@test Triple(Blank("box$(fv)_out1"), R("monocl","wire"), Blank("box$(gv)_in1")) in stmts

# Check wires between special input and output nodes.
@test all(stmt in stmts for stmt in [
  Triple(Blank("box$(vin)_out1"), R("monocl","wire"), Blank("box$(fv)_in1")),
  Triple(Blank("box$(vin)_out2"), R("monocl","wire"), Blank("box$(hv)_in1")),
  Triple(Blank("box$(gv)_out1"), R("monocl","wire"), Blank("box$(vout)_in1")),
  Triple(Blank("box$(hv)_out1"), R("monocl","wire"), Blank("box$(vout)_in2")),
])

# Test that above wiring diagram can be stored as named graph.
graph = Resource("ex", "diagram")
stmts = wiring_diagram_to_rdf(diagram; graph=graph)

@test Triple(graph, R("rdf","type"), R("monocl","WiringDiagram")) in stmts
@test Quad(Blank("box$(fv)"), R("rdf","type"), R("monocl","Box"), graph) in stmts
@test Quad(Blank("box$(fv)_in1"), R("rdf","type"), R("monocl","Port"), graph) in stmts
@test Quad(Blank("box$(fv)_out1"), R("rdf","type"), R("monocl","Port"), graph) in stmts

end
