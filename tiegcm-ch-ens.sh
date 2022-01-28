#!/bin/bash
#
#  build TIEGCM and setup ensemble for DART on the NCAR supercomputer Cheyenne.
#
# Set shell variables and #PBS settings below:
#
#   modeldir:  Root directory to model source (may be an SVN working dir)
#   execdir:   Directory in which to build and execute (will be created if necessary)
#   tgcmdata:  Directory in which startup history and data files are accessed.
#              (If tgcmdata is not set, the model will use env var TGCMDATA)
#   input:     Namelist input file for the chosen model resolution
#   output:    Stdout file from model execution (will be created)
#   modelres:  Model resolution (5.0 or 2.5 degrees)
#   make:      Build file with platform-specific compile parameters (in scripts dir)
#   mpi:       TRUE/FALSE for MPI run (non-MPI runs are not supported in v2.0 and later)
#   debug:     If TRUE, build and execute a "debug" run (debug compiler flags are set)
#   exec:      If TRUE, execute the model (build only if exec is FALSE)
#   utildir:   Directory containing supporting scripts (default $modeldir/scripts)
#   runscript: LSF script with run commands (submitted with bsub from execdir)
#
# To switch to 2.5-deg resolution, set modelres below to 2.5, 
# and change execdir, tgcmdata and namelist input as necessary.
# Also reset number of processors accordingly below (#BSUB -n).
#

set -e

modelres=2.5
modeldir=tiegcm2.0
execdir=tiegcm.exec${modelres}
tgcmdata=/glade/scratch/hkershaw/DART/TIEGCM/DATA/tiegcm_res${modelres}_data
input=tiegcm_res${modelres}.inp
output=tiegcm_res${modelres}.out
make=Make.intel_ch
mpi=TRUE   # (must be TRUE for tiegcm2.0 or later)
debug=FALSE
utildir=$modeldir/scripts
runscript=run${modelres}.pbs

execdir=$(perl $utildir/abspath $execdir)
runscript=$(perl $utildir/abspath $runscript)

[ ! -d $execdir ] && mkdir -p $execdir
#
# Set LSF resource usage (create the runscript in execdir):
# (run commands are appended to this script below)
#
cat << EOF > $runscript
#!/bin/bash
#
#PBS -A P86850054
#PBS -N tiegcm2.0
#PBS -j oe
#PBS -k eod
#PBS -q regular
#PBS -l walltime=00:20:00
##PBS -l select=1:ncpus=16:mpiprocs=16
#PBS -l select=1:ncpus=32:mpiprocs=32:ompthreads=1

export TMPDIR=/glade/scratch/$USER/temp
mkdir -p $TMPDIR
#
EOF
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#                               End user settings
#                        Shell Script for TIEGCM Linux job
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
# ESMF module Cheyenne note double load
module load intel/19.0.2
module load mpt/2.21
module load esmf_libs/7.1.0r
module load esmf-7.1.0r-ncdfio-mpi-O  
#
mycwd=$(pwd)
echo "" ; echo "${0}:"
echo "  Begin execution at `date`"
echo "  Current working directory: $mycwd"
echo "  System: `uname -a`"  
echo ""
#
# Verify directories and make_machine file (make execdir if necessary).
# Get absolute path for dirs that are accessed from the execdir.
#
[ ! -d $modeldir ] && echo ">>> Cannot find model directory $modeldir <<<" && exit 1

#
# Executable file name:
model=tiegcm.exe

[ ! -d $utildir ] && echo ">>> Cannot find model scripts directory $utildir <<<"  && exit 1

utildir=$(perl $utildir/abspath $utildir)

srcdir=$modeldir/src
[ ! -d $srcdir ] && echo ">>> Cannot find model source directory $srcdir <<<" && exit 1

set srcdir = `perl $utildir/abspath $srcdir`
#
# data directory:
[ ! -d $tgcmdata ] &&  echo ">>> Cannot find data directory $tgcmdata" && exit 1

if [ $modelres != 5.0 ] && [ $modelres != 2.5 ] 
then
  echo ">>> Unknown model resolution $modelres <<<"
  exit 1
fi

#
# Copy make files to execdir if necessary:
#
[ ! -f $execdir/$make ] && cp $utildir/$make $execdir
[ ! -f $execdir/Makefile ] && $utildir/Makefile $execdir
[ ! -f $execdir/mkdepends ] && $utildir/mkdepends $execdir
#
# Make default namelist input file if not provided by user:
#
[ ! -f $input ] && echo ">>> Cannot find namelist input file $input <<<" && exit 1

model=$execdir/$model
input=$(perl $utildir/abspath $input)
output=$(perl $utildir/abspath $output)
util=$(perl $utildir/abspath $utildir)
mklogs=$util/mklogs         # Nov, 2015: mklogs rewritten in python
rmbinchars=$util/rmbinchars # Nov, 2015: remove non-ascii chars from stdout files
#
# Report to stdout:
#
#set svn_revision = `svnversion $modeldir` || set svn_revision = "[none]"
 set svn_revision = 'tiegcm2.0' # for svn tag instead of revision number

echo -n "  Model directory:   $modeldir" && echo " (SVN revision $svn_revision)"
echo "  Exec directory:    $execdir"
echo "  Source directory:  $srcdir"
echo "  Data directory:    $tgcmdata"
echo "  Make machine file: $make"
echo "  Namelist input:    $input"
echo "  Stdout Output:     $output"
echo "  Model resolution:  $modelres"
echo "  Debug:             $debug"
echo "  MPI job:           $mpi"

#
# If debug flag has changed from last gmake, clean execdir
# and reset debug file:
#
if [ -f $execdir/debug ] 
then
  lastdebug=$(cat $execdir/debug) 
  if [ $lastdebug != $debug ] 
  then
    echo "Clean execdir $execdir because debug flag switched from $lastdebug to $debug"
    mycwd=$(pwd) ; cd $execdir ; gmake clean ; cd $mycwd
    echo $debug > $execdir/debug
  fi
else
  echo $debug > $execdir/debug
  echo "Created file debug with debug flag = $debug"
fi
#
# If mpi flag has changed from last gmake, clean execdir
# and reset mpi file:
#
if [ -f $execdir/mpi ] 
then
  lastmpi=$(cat $execdir/mpi) 
  if [ $lastmpi != $mpi ] 
  then
    echo "Clean execdir $execdir because mpi flag switched from $lastmpi to $mpi"
    mycwd $(pwd) ; cd $execdir ; gmake clean ; cd $mycwd
    echo $mpi > $execdir/mpi
  fi
else
  echo $mpi > $execdir/mpi
  echo "Created file mpi with mpi flag = $mpi"
fi
#
# Copy defs header file to execdir, if necessary, according to 
# requested resolution. This should seamlessly switch between
# resolutions according to $modelres.
#
defs=$srcdir/defs5.0
[ $modelres == 2.5 ] && defs=$srcdir/defs2.5
if [ -f $execdir/defs.h ]
then
  cmp -s $execdir/defs.h $defs
  if [ $? == 1 ] 
  then # files differ -> switch resolutions
    echo "Switching defs.h for model resolution $modelres"
    cp $defs $execdir/defs.h
  else
    echo "defs.h already set for model resolution $modelres"
  fi 
else # defs.h does not exist in execdir -> copy appropriate defs file
  echo "Copying $defs to $execdir/defs.h for resolution $modelres"
  cp $defs $execdir/defs.h
fi

#
# cd to execdir and run make:
#
echo $execdir
cd $execdir 
echo ""
echo "Begin building $model in $(pwd)"
#
# Build Make.env file in exec dir, containing needed env vars for Makefile:
#
cat << EOF > Make.env
MAKE_MACHINE  = $make
DIRS          = . $srcdir 
MPI           = $mpi
EXECNAME      = $model
NAMELIST      = $input
OUTPUT        = $output
DEBUG         = $debug
SVN_REVISION  = $svn_revision
EOF
#
# Build the model:
gmake -j8 all 
#
#
# Set data directory in LSF script:
#
cat << EOF >> $runscript
  export TGCMDATA=$tgcmdata
EOF
#
# MPI/LSF job: append mpirun.lsf command to LSF script 
# (it has #BSUBs from above)
#
cat << EOF >> $runscript
export MP_LABELIO=YES
export MP_SHARED_MEMORY=yes
#
# Execute:
  mpiexec_mpt $model $input &> $output
#
# Save stdout:
  $rmbinchars $output # remove any non-ascii chars in stdout file
  $mklogs $output     # break stdout into per-task log files
  cd $output:h
#
# Make tar file of task log files:
  tar -cf $output.tar *task*.out 
  echo Saved stdout tar file $output.tar 
  rm *task*.out
EOF
exit 0
