import vapoursynth as vs

# read source from stdin and write back to output
core = vs.get_core()

source = core.raws.Source(source='/dev/stdin')

source.set_output()
