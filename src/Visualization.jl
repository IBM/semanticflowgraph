""" Visualize raw and semantic flow graphs.
"""
module Visualization

using Compat

using Catlab.WiringDiagrams, Catlab.Graphics
import Catlab.Graphics.WiringDiagramLayouts: box_label, wire_label
using ..Doctrine
using ..RawFlowGraphs
import ..Serialization: text_label

# Raw flow graphs
#################

# FIXME: These methods use language-specific attributes. Perhaps there should
# be some standardization across languages.

function box_label(::MIME"text/plain", node::RawNode)
  lang = node.language
  get_first(lang, ["slot", "qual_name", "function", "kind"], "")
end

function wire_label(::MIME"text/plain", port::RawPort)
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

box_label(::MIME"text/plain", f::Monocl.Hom) = text_label(f)
wire_label(::MIME"text/plain", A::Monocl.Ob) = text_label(A)

end
