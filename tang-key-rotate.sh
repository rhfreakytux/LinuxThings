#!/bin/sh

# Author: Narayan Pun Magar
# Date: 01/16/2023
# Description: Rotating Tang Server Keys and Removing Old keys

## Run with sudo or be root, should be done in tang server side

TANG_DB=/var/db/tang

cd $TANG_DB

for i in *; do
    rm $i; done
    
/usr/libexec/tangd-keygen $TANG_DB
