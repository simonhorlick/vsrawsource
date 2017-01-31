import vapoursynth as vs

# read source from stdin and write back to output
core = vs.get_core()

fmt = fmt_.decode('utf8').split(':')

width   = int(fmt[0])
height  = int(fmt[1])
src_fmt = fmt[2]
#dst_fmt = eval('vs.%s' % fmt[3])
swap_rgb = int(fmt[3])
swap_uv = int(fmt[4])
align = 1

source = core.raws.Source(
    source  = '-',
    width   = width,
    height  = height,
    src_fmt = src_fmt,
    rowbytes_align = align)

# alpha formats give back two clips, we have to
# test one or the other since they can't be merged into output
if type(source) is list:
    source = source[0]

if swap_rgb and source.format.color_family == vs.RGB:
    source = core.std.ShufflePlanes(source, [1, 2, 0], colorfamily=vs.RGB)

if swap_uv and source.format.color_family == vs.YUV:
    source = core.std.ShufflePlanes(source, [0, 2, 1], colorfamily=vs.YUV)

#source = core.resize.Bicubic(source, format=dst_fmt)

source.set_output()
