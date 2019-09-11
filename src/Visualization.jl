""" Visualization of flow graphs as Graphviz and TikZ diagrams.
"""
module Visualization

using Compat

using Catlab.WiringDiagrams, Catlab.Graphics
using ..Doctrine
using ..RawFlowGraphs
import ..Serialization: text_label

const Graphviz = GraphvizWiringDiagrams
const TikZ = TikZWiringDiagrams

# Raw flow graphs
#################

# Graphviz support.
# FIXME: These methods use language-specific attributes. Perhaps there should
# be some standardization across languages.

function Graphviz.node_label(node::RawNode)
  lang = node.language
  get_first(lang, ["slot", "qual_name", "function", "kind"], "?")
end

function Graphviz.edge_label(port::RawPort)
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
Graphviz.node_label(f::Monocl.Hom) = text_label(f)

function Graphviz.node_label(f::Union{Monocl.Hom,Nothing})
  isnothing(f) ? "?" : text_label(f)
end
function Graphviz.edge_label(A::Union{Monocl.Ob,Nothing})
  isnothing(A) ? "" : text_label(A)
end

# TikZ support.
function TikZ.box(name::String, f::Monocl.Hom{:generator})
  TikZ.rect(name, f)
end
function TikZ.box(name::String, f::Monocl.Hom{:mcopy})
  TikZ.junction_circle(name, f)
end
function TikZ.box(name::String, f::Monocl.Hom{:delete})
  TikZ.junction_circle(name, f)
end
function TikZ.box(name::String, f::Monocl.Hom{:coerce})
  TikZ.trapezium(name, text_label(f), TikZ.wires(dom(f)), TikZ.wires(codom(f)))
end
function TikZ.box(name::String, f::Monocl.Hom{:construct})
  TikZ.rect(name, text_label(f), TikZ.wires(dom(f)), TikZ.wires(codom(f)))
end

end
