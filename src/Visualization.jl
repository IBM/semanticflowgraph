""" Visualization of flow graphs as Graphviz and TikZ diagrams.
"""
module Visualization

using Nullables

using Catlab.WiringDiagrams, Catlab.Graphics
using ..Doctrine
using ..RawFlowGraphs

# Raw flow graphs
#################

# Graphviz support.
# FIXME: These methods use language-specific attributes. Perhaps there should
# be some standardization across languages.

function GraphvizWiring.node_label(node::RawNode)
  lang = node.language
  get_first(lang, ["slot", "qual_name", "function", "kind"], "?")
end

function GraphvizWiring.edge_label(port::RawPort)
  lang = port.language
  get_first(lang, ["qual_name", "class"], "")
end

function get_first(collection, keys, default)
  if isempty(keys); return default end
  get(collection, splice!(keys, 1)) do
    get_first(collection, keys, default)
  end
end

# Semantic flow graphs
######################

# Graphviz support.
GraphvizWiring.node_label(f::Monocl.Hom{:coerce}) = "to"
GraphvizWiring.node_id(f::Monocl.Hom{:coerce}) = ":coerce"

GraphvizWiring.node_label(f::Monocl.Hom{:construct}) = string(codom(f))
GraphvizWiring.node_id(f::Monocl.Hom{:construct}) = ":construct"

function GraphvizWiring.node_label(f::Nullable{Monocl.Hom})
  isnull(f) ? "?" : GraphvizWiring.node_label(get(f))
end
function GraphvizWiring.node_id(f::Nullable{Monocl.Hom})
  isnull(f) ? "" : GraphvizWiring.node_id(get(f))
end
function GraphvizWiring.edge_label(A::Nullable{Monocl.Ob})
  isnull(A) ? "" : GraphvizWiring.edge_label(get(A))
end

# TikZ support.
function TikZWiring.box(name::String, f::Monocl.Hom{:generator})
  TikZWiring.rect(name, f)
end
function TikZWiring.box(name::String, f::Monocl.Hom{:mcopy})
  TikZWiring.junction_circle(name, f)
end
function TikZWiring.box(name::String, f::Monocl.Hom{:delete})
  TikZWiring.junction_circle(name, f)
end
function TikZWiring.box(name::String, f::Monocl.Hom{:coerce})
  TikZWiring.trapezium(
    name,
    "to",
    TikZWiring.wires(dom(f)),
    TikZWiring.wires(codom(f))
  )
end
function TikZWiring.box(name::String, f::Monocl.Hom{:construct})
  TikZWiring.rect(
    name,
    string(codom(f)),
    TikZWiring.wires(dom(f)),
    TikZWiring.wires(codom(f))
  )
end

end