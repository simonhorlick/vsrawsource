import vapoursynth as vs
import pprint as pp

filePath = file_.decode('utf-8')
formatCode = eval('vs.%s' % format_.decode('utf-8'))

# get the core instance
core = vs.get_core()

#core.std.LoadPlugin('/usr/local/lib/libffms2.so')

source = core.ffms2.Source(source=filePath)

source = core.resize.Bicubic(source, format=formatCode)

# set the clip to be output
source.set_output()
