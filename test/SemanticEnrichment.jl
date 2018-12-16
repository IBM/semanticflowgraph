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

module TestSemanticEnrichment
using Test

using Catlab.WiringDiagrams
using SemanticFlowGraphs

const db_filename = joinpath(@__DIR__, "ontology", "data", "employee.json")
db = OntologyDB()
load_ontology_file(db, db_filename)

# Convenience methods to create raw boxes and wires with or without annotations.
const prefix = "opendisc/employee"
add_raw_box!(f::WiringDiagram, args...; kw...) =
  add_box!(f, raw_box(args...; kw...))
raw_box(inputs, outputs; kw...) =
  Box(RawNode(; kw...), raw_ports(inputs), raw_ports(outputs))
raw_box(name::String, inputs, outputs) =
  Box(RawNode(annotation="$prefix/$name"), raw_ports(inputs), raw_ports(outputs))
raw_ports(n::Int) = RawPort[ RawPort() for i in 1:n ]
raw_ports(xs::Vector) = RawPort[ raw_port(x) for x in xs ]
raw_port(::Nothing) = RawPort()
raw_port(name::String) = RawPort(annotation="$prefix/$name")
raw_port(name::String, index::Int) =
  RawPort(annotation="$prefix/$name", annotation_index=index)
raw_port(args::Tuple) = raw_port(args...)

# Expand single annotated box.
f = WiringDiagram(raw_ports(["employee"]), raw_ports(["employee"]))
v = add_raw_box!(f, "manager", [("employee",1)], [("employee",1)])
add_wires!(f, [
  (input_id(f),1) => (v,1),
  (v,1) => (output_id(f),1)
])
actual = to_semantic_graph(db, f; elements=false)
target = WiringDiagram(concepts(db, ["employee"]), concepts(db, ["employee"]))
reports_to = add_box!(target, concept(db, "reports-to"))
add_wires!(target, [
  (input_id(target), 1) => (reports_to, 1),
  (reports_to, 1) => (output_id(target), 1),
])
@test actual == target

# Expand slots.
f = WiringDiagram(raw_ports(["employee"]), raw_ports(["department","str","str"]))
manager = add_raw_box!(f, "manager", [("employee",1)], [("employee",1)])
dept = add_raw_box!(f, "employee-department", [("employee",1)], [("department",1)])
first_name = add_raw_box!(f, [("employee",1)], [("str",1)],
                          annotation="$prefix/employee",
                          annotation_index=1, annotation_kind=SlotAnnotation)
last_name = add_raw_box!(f, [("employee",1)], [("str",1)],
                         annotation="$prefix/employee",
                         annotation_index=2, annotation_kind=SlotAnnotation)
add_wires!(f, [
  (input_id(f), 1) => (manager, 1),
  (manager, 1) => (dept, 1),
  (manager, 1) => (first_name, 1),
  (manager, 1) => (last_name, 1),
  (dept, 1) => (output_id(f), 1),
  (first_name, 1) => (output_id(f), 2),
  (last_name, 1) => (output_id(f), 3),
])
actual = to_semantic_graph(db, f; elements=false)
target = WiringDiagram(concepts(db, ["employee"]),
                       concepts(db, ["department", "string", "string"]))
reports_to = add_box!(target, concept(db, "reports-to"))
works_in = add_box!(target, concept(db, "works-in"))
first_name = add_box!(target, concept(db, "person-first-name"))
last_name = add_box!(target, concept(db, "person-last-name"))
add_wires!(target, [
  (input_id(target), 1) => (reports_to, 1),
  (reports_to, 1) => (works_in, 1),
  (reports_to, 1) => (first_name, 1),
  (reports_to, 1) => (last_name, 1),
  (works_in, 1) => (output_id(target), 1),
  (first_name, 1) => (output_id(target), 2),
  (last_name, 1) => (output_id(target), 3),
])
@test actual == target

# Collapse adjacent unannotated boxes.
f = WiringDiagram(raw_ports(1), raw_ports(1))
u = add_raw_box!(f, 1, 1)
v = add_raw_box!(f, 1, 1)
add_wires!(f, [
  (input_id(f),1) => (u,1),
  (u,1) => (v,1),
  (v,1) => (output_id(f),1)
])
actual = to_semantic_graph(db, f; elements=false)
target = WiringDiagram([nothing], [nothing])
v = add_box!(target, Box(nothing, [nothing], [nothing]))
add_wires!(target, [
  (input_id(target), 1) => (v,1),
  (v,1) => (output_id(target), 1),
])
@test actual == target

# Don't collapse adjacent unannotated boxes with an intermediate annotated box.
f = WiringDiagram(raw_ports(0), raw_ports(0))
u = add_raw_box!(f, [], [nothing, "employee"])
v = add_raw_box!(f, [nothing, "employee"], [])
manager = add_raw_box!(f, "manager", [("employee",1)], [("employee",1)])
add_wires!(f, [
  (u,1) => (v,1),
  (u,2) => (manager,1),
  (manager,1) => (v,2),
])
actual = to_semantic_graph(db, f; elements=false)
target = WiringDiagram([], [])
u = add_box!(target, Box(nothing, [], [nothing, concept(db,"employee")]))
v = add_box!(target, Box(nothing, [nothing, concept(db,"employee")], []))
reports_to = add_box!(target, concept(db,"reports-to"))
add_wires!(target, [
  (u,1) => (v,1),
  (u,2) => (reports_to,1),
  (reports_to,1) => (v,2),
])
@test actual == target

# Don't assume that collapsibility is a transitive relation.
f = WiringDiagram(raw_ports(0), raw_ports(0))
u = add_raw_box!(f, [], [nothing, "employee"])
v = add_raw_box!(f, 1, 1)
w = add_raw_box!(f, [nothing, "employee"], [])
manager = add_raw_box!(f, "manager", [("employee",1)], [("employee",1)])
add_wires!(f, [
  (u,1) => (v,1),
  (v,1) => (w,1),
  (u,2) => (manager,1),
  (manager,1) => (w,2),
])
actual = to_semantic_graph(db, f; elements=false)
target = WiringDiagram([], [])
reports_to = add_box!(target, concept(db,"reports-to"))
u = add_box!(target, Box(nothing, [], [concept(db,"employee"), nothing]))
v = add_box!(target, Box(nothing, [nothing, concept(db,"employee")], []))
add_wires!(target, [
  (u,2) => (v,1),
  (u,1) => (reports_to,1),
  (reports_to,1) => (v,2),
])
@test actual == target

end
