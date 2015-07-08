#!/bin/sh

#  compileandlink.sh
#  DeafShark
#
#  Created by Bradley Slayter on 7/2/15.
#  Copyright © 2015 Flipped Bit. All rights reserved.

/usr/local/bin/llc $1 -o $2
cc $2 -o $3 -lc
rm $1 $2


