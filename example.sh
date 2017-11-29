#!/bin/bash
HOME=$PWD
tar zxvf MOODS-*
cd MOODS/src
make
cd ../python
python setup.py build
cd $HOME
export PYTHONPATH=$PYTHONPATH:./MOODS/python/build/lib.linux-x86_64-2.7

module load python/2.7.5

BACKGROUND_SCANS=100
DISTANCE=10
THRESHOLD=0.6

test -f ./example.fa || gunzip ./example.fa.gz

./cosmo_v1.py -fa ./example.fa -t $THRESHOLD -d $DISTANCE -p ./jpwm/ &

./cosmo_v1.py -fa ./example.fa -t $THRESHOLD -d $DISTANCE -p ./jpwm/ &

./cosmo_v1.py -fa ./example.fa -t $THRESHOLD -d $DISTANCE -p ./jpwm/ -C &

for i in {1..$BACKGROUND_SCANS}
do
./cosmo_v1.py -fa ./example.fa -t $THRESHOLD -d $DISTANCE -p ./jpwm/ -s -N $i
done

./cosmostats_v1.py -N $BACKGROUND_SCANS > stats.tab
