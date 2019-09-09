using Compat
using .PyCall

@pyimport flowgraph.core.record as PyFlowGraphs
@pyimport flowgraph.core.annotation_db as PyAnnotationDBs

function record_file(inpath::String, outpath::String, args::Dict, ::Val{:python})
  if isnothing(args["annotations"])
    db = nothing
  else
    # XXX: Why can't I just write `db.load_file`?
    db = PyAnnotationDBs.AnnotationDB()
    py"$(db).load_file"(abspath(args["annotations"]))
  end
  PyFlowGraphs.record_script(
    inpath, out=outpath, cwd=dirname(inpath), db=db,
    graph_outputs=args["graph-outputs"], store_slots=false)
end
