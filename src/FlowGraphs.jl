""" Datatypes for the raw and semantic flow graphs.
"""
module FlowGraphs
export MonoclElem, RawNode, RawPort, RawNodeAnnotationKind,
  FunctionAnnotation, ConstructAnnotation, SlotAnnotation,
  read_raw_graph, read_raw_graph_file,
  read_semantic_graph, read_semantic_graph_file

using AutoHashEquals, Parameters
import LightXML

using Catlab.Diagram
using ..Doctrine

# Raw flow graph
################

@enum(RawNodeAnnotationKind,
  FunctionAnnotation = 0,
  ConstructAnnotation = 1,
  SlotAnnotation = 2)

function Base.convert(::Type{RawNodeAnnotationKind}, s::String)
  if (s == "function") FunctionAnnotation
  elseif (s == "construct") ConstructAnnotation
  elseif (s == "slot") SlotAnnotation
  else error("Unknown annotation kind \"$s\"") end
end

@with_kw struct RawNode
  language::Dict{String,Any} = Dict{String,Any}()
  annotation::Nullable{String} = Nullable{String}()
  annotation_index::Nullable{Int} = Nullable()
  annotation_kind::RawNodeAnnotationKind = FunctionAnnotation
end

@with_kw struct RawPort
  language::Dict{String,Any} = Dict{String,Any}()
  annotation::Nullable{String} = Nullable{String}()
  annotation_index::Nullable{Int} = Nullable()
  id::Nullable{String} = Nullable{String}()
  value::Nullable = Nullable()
end

# GraphML support.

""" Read raw flow graph from GraphML.
"""
function read_raw_graph(xdoc::LightXML.XMLDocument)
  GraphML.read_graphml(RawNode, RawPort, Void, xdoc)
end
read_raw_graph(xml::String) = read_raw_graph(LightXML.parse_string(xml))
read_raw_graph_file(args...) = read_raw_graph(LightXML.parse_file(args...))

function GraphML.convert_from_graphml_data(::Type{RawNode}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  annotation_index = Nullable{Int}(pop!(data, "annotation_index", nothing))
  annotation_kind_str = Nullable{String}(pop!(data, "annotation_kind", nothing))
  annotation_kind = isnull(annotation_kind_str) ? FunctionAnnotation :
    convert(RawNodeAnnotationKind, get(annotation_kind_str))
  RawNode(data, annotation, annotation_index, annotation_kind)
end

function GraphML.convert_from_graphml_data(::Type{RawPort}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  annotation_index = Nullable{Int}(pop!(data, "annotation_index", nothing))
  id = Nullable{String}(pop!(data, "id", nothing))
  value = pop!(data, "value", Nullable())
  RawPort(data, annotation, annotation_index, id, value)
end

# Graphviz support.

function GraphvizWiring.node_label(node::RawNode)
  # FIXME: "qual_name" is Python-specific. Standarize some of these attributes?
  lang = node.language
  get(lang, "qual_name", get(lang, "name", "?"))
end

function GraphvizWiring.edge_label(port::RawPort)
  lang = port.language
  get(lang, "qual_name", get(lang, "name", ""))
end

# Semantic flow graph
#####################

""" Object in the Monocl category of elements.
"""
@auto_hash_equals struct MonoclElem
  ob::Nullable{Monocl.Ob}
  id::Nullable{String}
  value::Nullable
end
MonoclElem(ob; id=Nullable{String}(), value=Nullable()) = MonoclElem(ob, id, value)

# GraphML support.

""" Read semantic flow graph from GraphML.
"""
function read_semantic_graph(xdoc::LightXML.XMLDocument; elements::Bool=true)
  GraphML.read_graphml(
    Nullable{Monocl.Hom},
    !elements ? Nullable{Monocl.Ob} : MonoclElem,
    Void, xdoc)
end
function read_semantic_graph(xml::String; kw...)
  read_semantic_graph(LightXML.parse_string(xml); kw...)
end
function read_semantic_graph_file(args...; kw...)
  read_semantic_graph(LightXML.parse_file(args...); kw...)
end

function GraphML.convert_from_graphml_data(::Type{MonoclElem}, data::Dict)
  ob = haskey(data, "ob") ?
    parse_json_sexpr(Monocl, data["ob"]; symbols=false) : nothing
  id = get(data, "id", nothing)
  value = get(data, "value", Nullable())
  MonoclElem(ob, id, value)
end

function GraphML.convert_to_graphml_data(elem::MonoclElem)
  data = Dict{String,Any}()
  if (!isnull(elem.ob)) data["ob"] = to_json_sexpr(get(elem.ob)) end
  if (!isnull(elem.id)) data["id"] = get(elem.id) end
  if (!isnull(elem.value)) data["value"] = get(elem.value) end
  return data
end

end
