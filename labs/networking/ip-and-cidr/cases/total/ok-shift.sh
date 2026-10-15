echo $((1 << (32 - $(cut -d/ -f2 block.txt)))) > total.txt
