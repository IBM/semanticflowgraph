module TestFlowGraphs
using Base.Test

using Catlab.Diagram
using OpenDiscCore

const pkg_dir = abspath(joinpath(@__DIR__, "..", ".."))
const py_raw_graph_dir = joinpath(pkg_dir,
  "lang", "python", "opendisc", "integration_tests", "data")

# Raw flow graph
################

# Deserialize Python raw flow graph from GraphML.
diagram = read_raw_graph_file(joinpath(py_raw_graph_dir, "pandas_read_sql.xml"))
@test nboxes(diagram) == 2
b1, b2 = boxes(diagram)
@test isnull(b1.value.annotation)
@test get(b2.value.annotation) == "python/pandas/read-sql-table"
@test [ get(p.annotation) for p in output_ports(b1) ] ==
  [ "python/sqlalchemy/engine" ]
@test [ get(p.annotation) for p in input_ports(b2)[1:2] ] ==
  [ "python/builtins/str", "python/sqlalchemy/engine" ]
@test [ get(p.annotation) for p in output_ports(b2) ] ==
  [ "python/pandas/data-frame" ]

end
