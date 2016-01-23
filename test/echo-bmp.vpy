import vapoursynth as vs

# read source from stdin and write back to output
core = vs.get_core()

source = core.raws.Source(source='/dev/stdin')

# alpha formats give back two clips, we have to
# test one or the other since they can't be merged into output
if type(source) is list:
    source = source[0]

# ffmpeg doesn't have rgb planar so convert to gbr for verification
source = core.std.ShufflePlanes(source, [1, 2, 0], colorfamily=vs.RGB)

source.set_output()

