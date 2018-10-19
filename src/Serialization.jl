""" Serialization of flow graphs to/from GraphML.
"""
module Serialization
export read_raw_graph, read_semantic_graph

using Nullables

using Catlab, Catlab.Diagram
using ..Doctrine
using ..RawFlowGraphs

# Raw flow graphs
#################

""" Read raw flow graph from GraphML.
"""
function read_raw_graph(xml)
  GraphML.read_graphml(RawNode, RawPort, Nothing, xml)
end

function GraphML.convert_from_graphml_data(::Type{RawNode}, data::Dict)
  annotation = to_nullable(String, pop!(data, "annotation", nothing))
  annotation_index = to_nullable(Int, pop!(data, "annotation_index", nothing))
  annotation_kind_str = to_nullable(String, pop!(data, "annotation_kind", nothing))
  annotation_kind = isnull(annotation_kind_str) ? FunctionAnnotation :
    convert(RawNodeAnnotationKind, get(annotation_kind_str))
  RawNode(data, annotation, annotation_index, annotation_kind)
end

function GraphML.convert_from_graphml_data(::Type{RawPort}, data::Dict)
  annotation = to_nullable(String, pop!(data, "annotation", nothing))
  annotation_index = to_nullable(Int, pop!(data, "annotation_index", nothing))
  value = to_nullable(Any, pop!(data, "value", nothing))
  RawPort(data, annotation, annotation_index, value)
end

to_nullable(T::Type, x) = x == nothing ? Nullable{T}() : Nullable{T}(x)

# Semantic flow graphs
######################

""" Read semantic flow graph from GraphML.
"""
function read_semantic_graph(xml; elements::Bool=true)
  GraphML.read_graphml(
    Nullable{Monocl.Hom},
    !elements ? Nullable{Monocl.Ob} : MonoclElem,
    Nothing, xml)
end

function GraphML.convert_from_graphml_data(::Type{Monocl.Ob}, data::Dict)
  parse_json_sexpr(Monocl, data["ob"]; symbols=false)
end
function GraphML.convert_from_graphml_data(::Type{Monocl.Hom}, data::Dict)
  parse_json_sexpr(Monocl, data["hom"]; symbols=false)
end
function GraphML.convert_to_graphml_data(expr::Monocl.Ob)
  Dict("ob" => to_json_sexpr(expr))
end
function GraphML.convert_to_graphml_data(expr::Monocl.Hom)
  Dict("hom" => to_json_sexpr(expr))
end

function GraphML.convert_from_graphml_data(::Type{MonoclElem}, data::Dict)
  ob = haskey(data, "ob") ?
    parse_json_sexpr(Monocl, data["ob"]; symbols=false) : nothing
  value = get(data, "value", Nullable())
  MonoclElem(ob, value)
end

function GraphML.convert_to_graphml_data(elem::MonoclElem)
  data = Dict{String,Any}()
  if (!isnull(elem.ob)) data["ob"] = to_json_sexpr(get(elem.ob)) end
  if (!isnull(elem.value)) data["value"] = get(elem.value) end
  return data
end

end