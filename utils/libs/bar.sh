#!/bin/bash

netmaskBar()
{
    bar=""

    for ((i=1; i<5; ++i));
    do
        bar=$bar$(echo "obase=2;$(echo $netmask | cut -f$i -d.)" | bc)
    done

    bar=$(echo $bar | grep -o '1' | wc -l)
}