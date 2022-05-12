#!/bin/bash

# To check exit code for each arry job 
# qhist -j 2667681 -l

num_cycles=8
MODEL_RUNS=$(qsub run2.5.pbs)

echo "Submitted " $MODEL_RUNS

for (( i=1; i<$num_cycles; i++))
do
  MODEL_RUNS=$(qsub -W depend=afterok:$MODEL_RUNS run2.5.pbs)
  echo "Submitted " $MODEL_RUNS
done


