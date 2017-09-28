module TestFlowGraph
using Base.Test

using Catlab.Diagram
using OpenDiscCore

const py_data_dir = abspath(joinpath(@__DIR__,
  "..", "..", "lang", "python", "opendisc", "integration_tests", "data"))

function read_py_raw_graph(name::String)
  read_raw_graph_file(joinpath(py_data_dir, "$name.xml"))
end

# Raw flow graph
################

# Deserialize raw flow graph from GraphML.
diagram = read_py_raw_graph("pandas_read_sql")
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

# TODO

end
