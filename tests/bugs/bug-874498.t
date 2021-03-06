#!/bin/bash
. $(dirname $0)/../include.rc
cleanup;

TEST glusterd
TEST pidof glusterd
TEST $CLI volume info;
TEST $CLI volume create $V0 replica 2  $H0:$B0/brick1 $H0:$B0/brick2;
TEST $CLI volume start $V0;


TEST glusterfs --volfile-server=$H0 --volfile-id=$V0 $M0;
B0_hiphenated=`echo $B0 | tr '/' '-'`
kill -9 `cat /var/lib/glusterd/vols/$V0/run/$H0$B0_hiphenated-brick1.pid` ;


echo "GLUSTER FILE SYSTEM" > $M0/FILE1
echo "GLUSTER FILE SYSTEM" > $M0/FILE2

FILEN=$B0"/brick2/.glusterfs/indices/xattrop/"

function get_gfid()
{
path_of_file=$1

gfid_value=`getfattr -d -m . $path_of_file -e hex 2>/dev/null |  grep trusted.gfid | cut --complement -c -15 | sed 's/\([a-f0-9]\{8\}\)\([a-f0-9]\{4\}\)\([a-f0-9]\{4\}\)\([a-f0-9]\{4\}\)/\1-\2-\3-\4-/'`

echo $gfid_value
}

GFID_ROOT=`get_gfid $B0/brick2`
GFID_FILE1=`get_gfid $B0/brick2/FILE1`
GFID_FILE2=`get_gfid $B0/brick2/FILE2`


count=0
for i in `ls $FILEN`
do
 if [ "$i" == "$GFID_ROOT" ] || [ "$i" == "$GFID_FILE1" ] || [ "$i" == "$GFID_FILE2" ]
        then
 count=$(( count + 1 ))
 fi
done

EXPECT "3" echo $count


TEST $CLI volume start $V0 force
sleep 5
TEST $CLI volume heal $V0 full
sleep 2

val1=0

##count the number of entries after self heal
for g in `ls $FILEN`
do
val1=$(( val1 + 1 ))
done
##Expected number of entries are 0 in the .glusterfs/indices/xattrop directory
EXPECT '0' echo $val1
TEST $CLI volume stop $V0;
TEST $CLI volume delete $V0;

cleanup;
