#!/bin/bash
#
#  test-y4m-formats.sh: Test y4m/yuv4mpeg-compatible formats
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

if [ -z $input ]; then
    echo "usage: $0 file"
    exit -1
fi

red="\x1b[31m"
green="\x1b[32m"
reset="\x1b[0m"

for fmt in \
    GRAY8 GRAY16 GRAYH GRAYS \
    YUV410P8 YUV411P8 YUV440P8 \
    YUV420P8 YUV420P9 YUV420P10 YUV420P16 \
    YUV422P8 YUV422P9 YUV422P10 YUV422P16 \
    YUV444P8 YUV444P9 YUV444P10 YUV444P16 YUV444PH YUV444PS
do
    echo -e \\n== $fmt ===============================

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
    
    if [ "$srcSum" = "$echoSum" ]; then
        echo -e ${green}PASS${reset}
        numPass=$(($numPass+1))
    else
        echo -e ${red}FAIL${reset}
        numFail=$(($numFail+1))
    fi
done

echo $0 \| PASS $numPass \| FAIL $numFail
