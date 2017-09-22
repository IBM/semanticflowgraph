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
@test [ get(box.value.annotation, nothing) for box in boxes(diagram) ] ==
      [ nothing, "python/pandas/read-sql-table" ]
@test [ get(wire.value.annotation, nothing) for wire in wires(diagram) ] ==
      [ "python/sqlalchemy/engine", "python/sqlalchemy/engine",
        "python/pandas/data-frame" ]

# Semantic flow graph
#####################

const db_filename = joinpath(@__DIR__, "ontology", "data", "employee.json")
db = OntologyDB()
load_ontology_file(db, db_filename)

# Convenience methods to create raw boxes and wires with or without annotations.
raw_box(nin::Int, nout::Int) = Box(RawNode(), raw_ports(nint), raw_ports(nout))
raw_box(annotation::String, inputs::Vector{Int}, outputs::Vector{Int}) =
  Box(RawNode(annotation=annotation), raw_ports(inputs), raw_ports(outputs))
raw_ports(n::Int) = [ RawPort() for i in 1:n ]
raw_ports(v::Vector{Int}) = [ RawPort(annotation=i) for i in v ]
raw_wire(src, tgt; kw...) = Wire(RawWire(; kw...), src, tgt)
raw_wire(pair::Pair; kw...) = Wire(RawWire(; kw...), pair)
add_raw_box!(f::WiringDiagram, args...) = add_box!(f, raw_box(args...))
add_raw_wire!(f::WiringDiagram, args...; kw...) =
  add_wire!(f, raw_wire(args...; kw...))

# Expand single annotated node.
f = WiringDiagram(raw_ports(1), raw_ports(1))
v = add_raw_box!(f, "opendisc/employee/manager", [1], [1])
add_raw_wire!(f, (input_id(f),1) => (v,1), annotation="opendisc/employee/employee")
add_raw_wire!(f, (v,1) => (output_id(f),1), annotation="opendisc/employee/employee")
actual = to_semantic_graph(db, f)
target = to_wiring_diagram(concept(db, "reports-to"))
@test actual == target

end
