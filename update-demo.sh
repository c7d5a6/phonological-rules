#!/bin/bash

CURRENT_DIR=$(pwd)
LIB_DIR="$CURRENT_DIR/phonological-rules-lib"
SERV_DIR="$CURRENT_DIR/phonological-rules-backend"

cd $LIB_DIR
zig build -Dtarget=x86_64-linux-gnu --release=fast --summary all
mv $LIB_DIR/zig-out/lib/libph_lib.so.0.1.0 $SERV_DIR/libs/libph_lib.so

cd $SERV_DIR
zig build -Dtarget=x86_64-linux-gnu --release=fast --summary all

scp $SERV_DIR/zig-out/bin/phonological-rules-backend foundry@foundry.owlbeardm.com:~/ph-lib/
scp $SERV_DIR/libs/libph_lib.so foundry@foundry.owlbeardm.com:~/ph-lib/libs/

ssh foundry@foundry.owlbeardm.com "pm2 restart 7"
