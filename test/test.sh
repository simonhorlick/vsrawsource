#!/bin/bash

# note: for checksum test, file codecs should not be h264 since decode
# is non-deterministic
input="$1"
numFrames=3
numPass=0
numFail=0
threads=1

red="\x1b[31m"
green="\x1b[32m"
reset="\x1b[0m"

# use fifo's so we don't capture any stray stdout
rm -f src.y4m
rm -f echo.y4m
mkfifo src.y4m
mkfifo echo.y4m

for fmt in \
    GRAY8 GRAY16 GRAYH GRAYS \
    YUV410P8 YUV411P8 YUV440P8 \
    YUV420P8 YUV420P9 YUV420P10 YUV420P16 \
    YUV422P8 YUV422P9 YUV422P10 YUV422P16 \
    YUV444P8 YUV444P9 YUV444P10 YUV444P16 YUV444PH YUV444PS
do

    echo -e \\n== $fmt ===============================

    # first pass, checksum the source clip w/o raws
    vspipe --requests $threads --arg file_="$input" --arg format_=$fmt --y4m --end $numFrames source.vpy src.y4m &
    
    # don't check the first line since it contains y4m XLENGTH comment which
    # for the pipe output is going to be INT32_MAX
    srcSum=`tail -n +2 src.y4m | openssl md5`
    
    # second pass, same source clip piped through raws
    vspipe --requests $threads --arg file_="$input" --arg format_=$fmt --y4m --end $numFrames source.vpy src.y4m &
    
    cat src.y4m | vspipe --requests $threads --y4m --end $numFrames echo.vpy echo.y4m  & 
    
    echoSum=`tail -n +2 echo.y4m | openssl md5`
    
    if [ "$srcSum" = "$echoSum" ]; then
        echo -e ${green}PASS${reset}
        numPass=$(($numPass+1))
    else
        echo -e ${red}FAIL${reset}
        numFail=$(($numFail+1))
    fi
done

echo $0 TESTED $(($numPass+$numFail)) \| PASS $numPass \| FAIL $numFail

echo -e ${reset}
unlink src.y4m
unlink echo.y4m
