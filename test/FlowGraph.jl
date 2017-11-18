module TestFlowGraph
using Base.Test

using Catlab.Diagram
using OpenDiscCore

# Semantic flow graph
#####################

const db_filename = joinpath(@__DIR__, "ontology", "data", "employee.json")
db = OntologyDB()
load_ontology_file(db, db_filename)

# Convenience methods to create raw boxes and wires with or without annotations.
const prefix = "opendisc/employee"
add_raw_box!(f::WiringDiagram, args...; kw...) =
  add_box!(f, raw_box(args...; kw...))
add_raw_wire!(f::WiringDiagram, pair::Pair; kw...) =
  add_wire!(f, Wire(RawWire(; kw...), pair))
add_raw_wires!(f::WiringDiagram, pairs) =
  add_wires!(f, [ Wire(RawWire(), pair) for pair in pairs ])
raw_box(inputs, outputs; kw...) =
  Box(RawNode(; kw...), raw_ports(inputs), raw_ports(outputs))
raw_box(name::String, inputs, outputs) =
  Box(RawNode(annotation="$prefix/$name"), raw_ports(inputs), raw_ports(outputs))
raw_ports(n::Int) = [ RawPort() for i in 1:n ]
raw_ports(xs::Vector) = [ raw_port(x) for x in xs ]
raw_port(name::String) = RawPort(annotation="$prefix/$name")
raw_port(name::String, index::Int) =
  RawPort(annotation="$prefix/$name", annotation_index=index)
raw_port(args::Tuple) = raw_port(args...)

# Expand single annotated node.
f = WiringDiagram(raw_ports(["employee"]), raw_ports(["employee"]))
v = add_raw_box!(f, "manager", [("employee",1)], [("employee",1)])
add_raw_wires!(f, [
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

# Expand slots, checking that IDs and values are retained.
f = WiringDiagram(raw_ports(["employee"]), raw_ports(["department","str","str"]))
manager = add_raw_box!(f, "manager", [("employee",1)], [("employee",1)])
dept = add_raw_box!(f, "employee-department", [("employee",1)], [("department",1)])
first_name = add_raw_box!(f, [("employee",1)], [("str",1)],
                          annotation="$prefix/employee",
                          annotation_index=1,
                          annotation_kind=FlowGraph.SlotAnnotation)
last_name = add_raw_box!(f, [("employee",1)], [("str",1)],
                         annotation="$prefix/employee",
                         annotation_index=2,
                         annotation_kind=FlowGraph.SlotAnnotation)
add_wires!(f, [
  Wire(RawWire(id="1"), (input_id(f), 1), (manager, 1)),
  Wire(RawWire(id="2"), (manager, 1), (dept, 1)),
  Wire(RawWire(id="2"), (manager, 1), (first_name, 1)),
  Wire(RawWire(id="2"), (manager, 1), (last_name, 1)),
  Wire(RawWire(id="3"), (dept, 1), (output_id(f), 1)),
  Wire(RawWire(value="John"), (first_name, 1), (output_id(f), 2)),
  Wire(RawWire(value="Doe"), (last_name, 1), (output_id(f), 3)),
])
actual = to_semantic_graph(db, f)
target = WiringDiagram(concepts(db, ["employee"]),
                       concepts(db, ["department", "string", "string"]))
reports_to = add_box!(target, concept(db, "reports-to"))
works_in = add_box!(target, concept(db, "works-in"))
first_name = add_box!(target, concept(db, "person-first-name"))
last_name = add_box!(target, concept(db, "person-last-name"))
add_wires!(target, [
  Wire(MonoclElem(id="1"), (input_id(target), 1), (reports_to, 1)),
  Wire(MonoclElem(id="2"), (reports_to, 1), (works_in, 1)),
  Wire(MonoclElem(id="2"), (reports_to, 1), (first_name, 1)),
  Wire(MonoclElem(id="2"), (reports_to, 1), (last_name, 1)),
  Wire(MonoclElem(id="3"), (works_in, 1), (output_id(target), 1)),
  Wire(MonoclElem(value="John"), (first_name, 1), (output_id(target), 2)),
  Wire(MonoclElem(value="Doe"), (last_name, 1), (output_id(target), 3)),
])
@test actual == target

# Collapse two unannotated nodes.
f = WiringDiagram(raw_ports(1), raw_ports(1))
u = add_raw_box!(f, 1, 1)
v = add_raw_box!(f, 1, 1)
add_raw_wires!(f, [
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

end
