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
#write_rdf(STDOUT, stmts, syntax="trig")

vs = box_ids(diagram)
vin, vout = input_id(diagram), output_id(diagram)
find_vertex = value -> vs[findfirst(v -> box(diagram, v).value == value, vs)]
fv, gv, hv = find_vertex(:f), find_vertex(:g), find_vertex(:h)

# Check RDF type of boxes and ports.
@test Triple(Blank("box$fv"), R("rdf","type"), R("cat","Box")) in stmts
@test Triple(Blank("box$fv-in1"), R("rdf","type"), R("cat","Port")) in stmts
@test Triple(Blank("box$fv-out1"), R("rdf","type"), R("cat","Port")) in stmts

# Check values of boxes and ports.
@test Triple(Blank("box$fv"), R("cat","value"), Literal("f")) in stmts
@test Triple(Blank("box$fv-in1"), R("cat","value"), Literal("A")) in stmts
@test Triple(Blank("box$fv-out1"), R("cat","value"), Literal("B")) in stmts

# Check RDF list representation of domain and codomain.
@test all(stmt in stmts for stmt in [
  Triple(Blank("box$fv"), R("cat","dom"), Blank("box$fv-dom1")),
  Triple(Blank("box$fv-dom1"), R("rdf","first"), Blank("box$fv-in1")),
  Triple(Blank("box$fv-dom1"), R("rdf","rest"), R("rdf","nil")),
  Triple(Blank("box$fv"), R("cat","codom"), Blank("box$fv-codom1")),
  Triple(Blank("box$fv-codom1"), R("rdf","first"), Blank("box$fv-out1")),
  Triple(Blank("box$fv-codom1"), R("rdf","rest"), R("rdf","nil")),
])

# Check special input and output nodes.
@test all(stmt in stmts for stmt in [
  Triple(Blank("box$vin-out1"), R("rdf","type"), R("cat","Port")),
  Triple(Blank("box$vin-out2"), R("rdf","type"), R("cat","Port")),
])
@test all(stmt in stmts for stmt in [
  Triple(Blank("box$vout-in1"), R("rdf","type"), R("cat","Port")),
  Triple(Blank("box$vout-in2"), R("rdf","type"), R("cat","Port")),
])

# Check wires.
@test Triple(Blank("box$fv-out1"), R("cat","wire"), Blank("box$gv-in1")) in stmts

# Check wires between special input and output nodes.
@test all(stmt in stmts for stmt in [
  Triple(Blank("box$vin-out1"), R("cat","wire"), Blank("box$fv-in1")),
  Triple(Blank("box$vin-out2"), R("cat","wire"), Blank("box$hv-in1")),
  Triple(Blank("box$gv-out1"), R("cat","wire"), Blank("box$vout-in1")),
  Triple(Blank("box$hv-out1"), R("cat","wire"), Blank("box$vout-in2")),
])

# Test that above wiring diagram can be stored as named graph.
graph = Resource("ex", "diagram")
stmts = wiring_diagram_to_rdf(diagram; graph=graph)

@test Triple(graph, R("rdf","type"), R("cat","WiringDiagram")) in stmts
@test Quad(Blank("box$fv"), R("rdf","type"), R("cat","Box"), graph) in stmts
@test Quad(Blank("box$fv-in1"), R("rdf","type"), R("cat","Port"), graph) in stmts
@test Quad(Blank("box$fv-out1"), R("rdf","type"), R("cat","Port"), graph) in stmts

end
