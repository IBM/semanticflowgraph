module TestFlowGraph
using Base.Test

using Catlab.Diagram
using OpenDiscCore

const pkg_dir = abspath(joinpath(@__DIR__, "..", ".."))
const py_data_dir = joinpath(pkg_dir,
  "lang", "python", "opendisc", "integration_tests", "data")
const dso_filename = joinpath(pkg_dir,
  "..", "data-science-ontology", "ontology.json")

# Raw flow graph
################

function read_py_raw_graph(name::String)
  read_raw_graph_file(joinpath(py_data_dir, "$name.xml"))
end

# Deserialize raw flow graph from GraphML.
diagram = read_py_raw_graph("pandas_read_sql")
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

# Semantic flow graph
#####################

db = OntologyDB()
load_ontology_file(db, dso_filename)

# Read SQL table using pandas and SQLAlchemy.
raw = read_py_raw_graph("pandas_read_sql")
semantic = to_semantic_graph(db, raw; elements=false)
d = WiringDiagram([], concepts(db, ["table"]))
engine = add_box!(d, Box(
  nothing, concepts(db, ["string"]), concepts(db, ["sql-database"])))
cons = add_box!(d, construct(pair(concept(db, "sql-table-database"),
                                  concept(db, "sql-table-name"))))
read = add_box!(d, concept(db, "read-table"))
add_wires!(d, [
  (engine, 1) => (cons, 1),
  (cons, 1) => (read, 1),
  (read, 1) => (output_id(diagram), 1),
])
@test semantic == d

# K-means clustering on the Iris dataset using sklearn.
raw = read_py_raw_graph("sklearn_clustering_kmeans")
semantic = to_semantic_graph(db, raw; elements=false)
d = WiringDiagram([], concepts(db, ["array"]))
filename = add_box!(d, construct(concept(db, "filename")))
read = add_box!(d, concept(db, "read-tabular-file"))
kmeans = add_box!(d, construct(concept(db, "k-means")))
transform = add_box!(d, Box(
  nothing, concepts(db, ["table"]), concepts(db, ["array"])))
fit = add_box!(d, concept(db, "fit"))
clusters = add_box!(d, concept(db, "clustering-model-clusters"))
add_wires!(d, [
  (filename, 1) => (read, 1),
  (read, 1) => (transform, 1),
  (kmeans, 1) => (fit, 1),
  (transform, 1) => (fit, 2),
  (fit, 1) => (clusters, 1),
  (clusters, 1) => (output_id(d), 1),
])
@test semantic == d

# Compare sklearn clustering models using a cluster similarity metric.
raw = read_py_raw_graph("sklearn_clustering_metrics")
semantic = to_semantic_graph(db, raw; elements=false)
d = WiringDiagram([], concepts(db, ["number"]))
make_data = add_box!(d, Box(
  nothing, [], concepts(db, ["array", "array"])))
kmeans = add_box!(d, construct(concept(db, "k-means")))
kmeans_fit = add_box!(d, concept(db, "fit"))
kmeans_clusters = add_box!(d, concept(db, "clustering-model-clusters"))
agglom = add_box!(d, construct(concept(db, "agglomerative-clustering")))
agglom_fit = add_box!(d, concept(db, "fit"))
agglom_clusters = add_box!(d, concept(db, "clustering-model-clusters"))
score = add_box!(d, Box(
  nothing, concepts(db, ["array", "array"]), concepts(db, ["number"])))
add_wires!(d, [
  (kmeans, 1) => (kmeans_fit, 1),
  (make_data, 1) => (kmeans_fit, 2),
  (kmeans_fit, 1) => (kmeans_clusters, 1),
  (agglom, 1) => (agglom_fit, 1),
  (make_data, 1) => (agglom_fit, 2),
  (agglom_fit, 1) => (agglom_clusters, 1),
  (kmeans_clusters, 1) => (score, 1),
  (agglom_clusters, 1) => (score, 2),
  (score, 1) => (output_id(d), 1),
])
@test semantic == d

end
