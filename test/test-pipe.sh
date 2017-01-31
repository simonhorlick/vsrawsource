#!/bin/bash
#
#  test-raw-formats.sh: Test raw/headerless formats
#
#  This file is a part of vsrawsource
#
#  Copyright (C) 2016  Darrell Walisser
#
#  Authors: Darrell Walisser (my.name at gmail dot com)
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with Libav; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#

input="$1"
numFrames=10
numPass=0
numFail=0
requests=1
red="\x1b[31m"
green="\x1b[32m"
reset="\x1b[0m"
    
if [ -z $input ]; then
    echo "usage: $0 file"
    exit -1
fi

# we need the width/height of the input since it can't
# be probed from a raw stream
ffprobe -show_streams "$input" 2>/dev/null > "$input.info"

width=`cat "$input.info" | grep ^width  | sed s/width=//`
height=`cat "$input.info"| grep ^height | sed s/height=//`

function split {
    arg=$1
    set -- `
        IFS=',';
        set -- $arg;

        echo $1 $2 $3
    `
    _1=$1
    _2=$2
    _3=$3
}

function compare {
    if [ "$1" = "$2" ]; then
        echo -e ${green}PASS${reset}
        numPass=$(($numPass+1))
    else
        echo -e ${red}FAIL${reset}
        numFail=$(($numFail+1))
    fi
}

# test formats in yuv4mpeg container
# vspipe(fmt) == vspipe(fmt) | vspipe
for fmt in \
    GRAY8 GRAY16 GRAYH GRAYS \
    YUV410P8 YUV411P8 YUV440P8 \
    YUV420P8 YUV420P9 YUV420P10 YUV420P16 \
    YUV422P8 YUV422P9 YUV422P10 YUV422P16 \
    YUV444P8 YUV444P9 YUV444P10 YUV444P16 YUV444PH YUV444PS
do
    echo -e \\n== Y4M $fmt ===============================

    # first pass, checksum the source clip w/o raws
    # don't check the first line since it contains y4m XLENGTH comment which
    # for the pipe output is going to be INT32_MAX
    srcSum=`vspipe --requests $requests --arg file_="$input" --arg format_=$fmt --y4m --end $((numFrames-1)) source.vpy - | \
            tail -n +2 | \
            openssl md5`

    # second pass, same source clip piped through raws
    echoSum=`vspipe --requests $requests --arg file_="$input" --arg format_=$fmt --y4m --end $((numFrames-1)) source.vpy - | \
            vspipe --requests $requests --y4m --end $((numFrames-1)) echo-y4m.vpy - | \
            tail -n +2 | \
            openssl md5`

    compare "$srcSum" "$echoSum"
done

# test (planar) formats that ffmpeg and vspipe can both output
# ffmpeg(fmt) == ffmpeg(fmt) | vspipe
for fmt in \
    yuv410p yuv411p yuv440p \
    yuv420p yuv420p9 yuv420p10 yuv422p16 \
    yuv422p yuv422p9 yuv422p10 yuv422p16 \
    yuv444p yuv444p9 yuv444p10 yuv444p16
do
    echo -e \\n== Planar $fmt ===============================

    # first pass, checksum the source clip w/o raws
    srcSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt $fmt -f rawvideo - | \
            openssl md5`
    
    # second pass, same source clip piped through raws
    echoSum=`ffmpeg -loglevel warning  -i "$input" -frames $numFrames -pix_fmt $fmt -f rawvideo - | \
            vspipe --requests $requests --end $(($numFrames-1)) --arg fmt_=$width:$height:$fmt:1:0 echo-raw.vpy - | \
            openssl md5`
    
    compare "$srcSum" "$echoSum"
done

# test packed formats against planar format vspipe outputs
# ffmpeg(fmt) | ffmpeg(planarFmt) == ffmpeg(fmt) | vspipe
for fmt in \
    nv12,yuv420p nv21,yuv420p \
    yuyv422,yuv422p yvyu422,yuv422p uyvy422,yuv422p \
    bgr24,gbrp rgb24,gbrp bgra,gbrp rgba,gbrp
do
    split $fmt
    packedFmt=$_1
    planarFmt=$_2

    echo -e \\n== Packed $packedFmt =\> $planarFmt ===============================

    # first pass, checksum the source clip w/o raws
    srcSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt $packedFmt -f rawvideo - | \
            ffmpeg -loglevel warning -f rawvideo -pixel_format $packedFmt -video_size ${width}x${height} \
                -i - -frames $numFrames -pix_fmt $planarFmt -f rawvideo - |
            openssl md5`

    # second pass, same source clip piped through raws
    echoSum=`ffmpeg -loglevel warning  -i "$input" -frames $numFrames -pix_fmt $packedFmt -f rawvideo - | \
            vspipe --requests $requests --end $(($numFrames-1)) --arg fmt_=$width:$height:$packedFmt:0:0 echo-raw.vpy - | \
            openssl md5`

    compare "$srcSum" "$echoSum"
done

# test rgb formats usable with bmp pipe
for fmt in \
    bgr24,gbrp bgra,gbrp
do
    split $fmt
    packedFmt=$_1
    planarFmt=$_2

    echo -e \\n== BMP $packedFmt =\> $planarFmt ===============================

    # first pass, checksum the source clip w/o raws
    srcSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt $packedFmt -c:v bmp -f rawvideo - | \
            ffmpeg -loglevel warning -i - -frames $numFrames -pix_fmt $planarFmt -f rawvideo - |
            openssl md5`

    # second pass, same source clip piped through raws
    echoSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt $packedFmt -c:v bmp -f rawvideo - | \
            vspipe --requests $requests --end $(($numFrames-1)) echo-bmp.vpy - | \
            openssl md5`

    compare "$srcSum" "$echoSum"
done

# test rgb formats that need rgb input (no sws yuv->rgb conversion exists)
# ffmpeg(rgb) | ffmpeg(fmt) | ffmpeg(planarFmt) == ffmpeg(rgb) | ffmpeg(fmt) | vspipe
for fmt in \
    bgr24,gbrp, bgra,gbrp abgr,gbrp argb,gbrp \
    gbrp,gbrp
do
    split $fmt
    packedFmt=$_1
    planarFmt=$_2

    echo -e \\n== RGB =\> $packedFmt =\> $planarFmt ===============================

    # first pass, checksum the source clip w/o raws
    srcSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt bgr24 -c:v bmp -f rawvideo - | \
            ffmpeg -loglevel warning -i - -frames $numFrames -pix_fmt $packedFmt -f rawvideo - | \
            ffmpeg -loglevel warning -f rawvideo -pixel_format $packedFmt -video_size ${width}x${height} \
                -i - -frames $numFrames -pix_fmt $planarFmt -f rawvideo - |
            openssl md5`

    # second pass, same source clip piped through raws
    echoSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt bgr24 -c:v bmp -f rawvideo - | \
            ffmpeg -loglevel warning -i - -frames $numFrames -pix_fmt $packedFmt -f rawvideo - | \
            vspipe --requests $requests --end $(($numFrames-1)) --arg fmt_=$width:$height:$packedFmt:0:0 echo-raw.vpy - | \
            openssl md5`

    compare "$srcSum" "$echoSum"
done

# test planar rgb formats vspipe can output
# ffmpeg(rgb) | vspipe(RGBXX) == ffmpeg(rgb) | vspipe(RGBXX) | vspipe(fmt)
for fmt in \
    gbrp,RGB24 gbrp9,RGB27 gbrp10,RGB30 gbrp16,RGB48
do
    split $fmt
    fmt=$_1
    srcFmt=$_2

    echo -e \\n== $srcFmt ===============================

    srcSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt bgr24 -f rawvideo - |
            vspipe --requests $requests --end $(($numFrames-1)) --arg fmt_=$width:$height:bgr24:$srcFmt:0 convert-raw.vpy - | \
            openssl md5`

    echoSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt bgr24 -f rawvideo - |
             vspipe --requests $requests --end $(($numFrames-1)) --arg fmt_=$width:$height:bgr24:$srcFmt:0 convert-raw.vpy - | \
             vspipe --requests $requests --end $(($numFrames-1)) --arg fmt_=$width:$height:$fmt:0:0 echo-raw.vpy - | \
            openssl md5`

    compare "$srcSum" "$echoSum"
done

# test using vspipe to get higher bit-depth gbrp,
# then ffmpeg to get desired format
# ffmpeg(rgb) | vspipe(gbrpXX) == ffmpeg(rgb) | vspipe(gbrpXX) | ffmpeg(fmt) | vspipe
for fmt in \
    rgb48,RGB48,gbrp16 \
    bgr48,RGB48,gbrp16 \
    gbrp16,RGB48,gbrp16 \
    gbrp10,RGB30,gbrp10 \
    gbrp9,RGB27,gbrp9
do
    split $fmt
    testFmt=$_1
    vsInFmt=$_2
    vsOutFmt=$_3

    echo -e \\n== HighRgb $testFmt ===============================

    srcSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt bgr24 -f rawvideo - | \
            vspipe --requests $requests --end $(($numFrames-1)) --arg fmt_=$width:$height:BGR:$vsInFmt:1 convert-raw.vpy - | \
            openssl md5`

    echoSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt bgr24 -f rawvideo - | \
            vspipe --requests $requests --end $(($numFrames-1))  --arg fmt_=$width:$height:BGR:$vsInFmt:1 convert-raw.vpy - | \
            ffmpeg -loglevel warning -f rawvideo -video_size ${width}x${height} -pixel_format $vsOutFmt -i - -pix_fmt $testFmt -f rawvideo - | \
            vspipe --requests $requests --end $(($numFrames-1)) --arg fmt_=$width:$height:$testFmt:0:0 echo-raw.vpy - | \
            openssl md5`

    compare "$srcSum" "$echoSum"
done

# test planar formats that have u/v swapped which are not in ffmpeg
# use vspipe for the swap
# ffmpeg(swapped) == ffmpeg(swapped) | vspipe(swapuv) | vspipe(fmt)
for fmt in \
    yvu9,yuv410p    \
    yv411,yuv411p   \
    yv12,yuv420p    \
    yv24,yuv444p
do
    split $fmt
    fmt=$_1
    swapped=$_2

    echo -e \\n== Swapped $fmt =\> $swapped ===============================

    srcSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt $swapped -f rawvideo - | \
            openssl md5`

    echoSum=`ffmpeg -loglevel warning -i "$input" -frames $numFrames -pix_fmt $swapped -f rawvideo - | \
            vspipe --requests $requests --end $(($numFrames-1)) --arg fmt_=$width:$height:$swapped:0:1 echo-raw.vpy - | \
            vspipe --requests $requests --end $(($numFrames-1)) --arg fmt_=$width:$height:$fmt:0:0 echo-raw.vpy - | \
            openssl md5`

    compare "$srcSum" "$echoSum"
done

echo ---------------------------------------------------
echo $0 \| PASS $numPass \| FAIL $numFail

# todo: untested
#
# alpha channel of argb, rgba etc
#
# p010
# p016
# vyuy422 (uyvy422 with swapped u/v)
# p210
# p216
# ayuv
#
