module TestFlowGraph
using Base.Test

using Catlab.Diagram
using OpenDiscCore.Ontology
using OpenDiscCore.FlowGraph

# Raw flow graph
################

# Deserialize raw flow graph from GraphML.
#
# Although this is a unit test, we'll use a Python raw graph for realism.
const py_data_dir = abspath(joinpath(
  @__DIR__, "..", "lang", "python", "opendisc", "integration_tests", "data"))

diagram = read_raw_graph_file(joinpath(py_data_dir, "pandas_read_sql.xml"))
@test nboxes(diagram) == 2
b1, b2 = boxes(diagram)
@test isnull(b1.value.annotation)
@test get(b2.value.annotation) == "python/pandas/read-sql-table"
@test [ get(p.annotation, nothing) for p in output_ports(b1) ] ==
  [ "python/sqlalchemy/engine" ]
@test [ get(p.annotation, nothing) for p in input_ports(b2)[1:2] ] ==
  [ nothing, "python/sqlalchemy/engine" ]
@test [ get(p.annotation, nothing) for p in output_ports(b2) ] ==
  [ "python/pandas/data-frame" ]

# Semantic flow graph
#####################

const db_filename = joinpath(@__DIR__, "ontology", "data", "employee.json")
db = OntologyDB()
load_ontology_file(db, db_filename)

# Convenience methods to create raw boxes and wires with or without annotations.
const prefix = "opendisc/employee"
add_raw_box!(f::WiringDiagram, args...) = add_box!(f, raw_box(args...))
raw_box(inputs, outputs) = Box(RawNode(), raw_ports(inputs), raw_ports(outputs))
raw_box(name::String, inputs, outputs) =
  Box(RawNode(annotation="$prefix/$name"), raw_ports(inputs), raw_ports(outputs))
raw_ports(n::Int) = [ RawPort() for i in 1:n ]
raw_ports(xs::Vector) = [ raw_port(x) for x in xs ]
raw_port(name::String) = RawPort(annotation="$prefix/$name")
raw_port(name::String, index::Int) =
  RawPort(annotation="$prefix/$name", index=index)
raw_port(args::Tuple) = raw_port(args...)

# Expand single annotated node.
f = WiringDiagram(raw_ports(["employee"]), raw_ports(["employee"]))
v = add_raw_box!(f, "manager", [("employee",1)], [("employee",1)])
add_wire!(f, (input_id(f),1) => (v,1))
add_wire!(f, (v,1) => (output_id(f),1))
actual = to_semantic_graph(db, f)
target = to_wiring_diagram(concept(db, "reports-to"))
@test actual == target

end
