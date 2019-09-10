using Compat
using .PyCall

const PyFlowGraphs = pyimport("flowgraph.core.record")
const PyAnnotationDBs = pyimport("flowgraph.core.annotation_db")

function record_file(inpath::String, outpath::String, args::Dict, ::Val{:python})
  if isnothing(args["annotations"])
    db = nothing
  else
    db = PyAnnotationDBs.AnnotationDB()
    db.load_file(abspath(args["annotations"]))
  end
  PyFlowGraphs.record_script(
    inpath, out=outpath, cwd=dirname(inpath), db=db,
    graph_outputs=args["graph-outputs"], store_slots=false)
end
