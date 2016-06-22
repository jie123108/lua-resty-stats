#!/bin/bash

for((i=0;i<10;i++));do
curl http://127.0.0.1:88/byuri/$RANDOM
curl http://127.0.0.1:88/byarg?client_type=pc
curl http://127.0.0.1:88/byarg?client_type=ios
curl http://127.0.0.1:88/byarg?client_type=android
curl http://127.0.0.1:88/byarg/404?client_type=android
curl http://127.0.0.1:88/byuriarg?from=partner
curl http://127.0.0.1:88/byuriarg?from=pc_cli
curl http://127.0.0.1:88/byuriarg?from=mobile_cli
curl http://127.0.0.1:88/byhttpheaderin -H"city: shanghai"
curl http://127.0.0.1:88/byhttpheaderin -H"city: shengzheng"
curl http://127.0.0.1:88/byhttpheaderin -H"city: beijing"
curl http://127.0.0.1:88/byhttpheaderout/hit
curl http://127.0.0.1:88/byhttpheaderout/miss
done;
