echo $(( 2 ** (32 - $(cut -d/ -f2 block.txt)) - 2 )) > usable.txt
