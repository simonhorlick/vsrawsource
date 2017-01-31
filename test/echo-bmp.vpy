import vapoursynth as vs

# read source from stdin and write back to output
core = vs.get_core()

source = core.raws.Source(source='-')

# alpha formats give back two clips, we have to
# test one or the other since they can't be merged into output
if type(source) is list:
    source = source[0]

source.set_output()
