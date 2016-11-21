#!/bin/sh -xe
# script to build the OpenModelica nightly-build
# Adrian Pop [adrian.pop@liu.se]
# 2013-10-03
#
# expects to have these things installed:
#  python 2.7.x (you need to run easy_install joblib simplejson requests in the cmd line in python\Scripts)
#  nsis installer
#  TortoiseSVN command line tools
#  Qt 4.8.0
#  jdk
#  git command line clients (PUT IT LAST IN THE PATH!) http://git-scm.com/downloads
#  OMDev in c:\OM19\OMDev
#

# get the ssh password via command line
export SSHUSER=$1
export MAKETHREADS=$2
export GIT_TAG=$3
export OPENMODELICA_BRANCH=$GIT_TAG

# set the path to our tools
export PATH=$PATH:/c/bin/python273:/c/Program\ Files/TortoiseSVN/bin/:/c/bin/jdk/bin:/c/bin/nsis/:/c/bin/QtSDK/Desktop/Qt/4.8.0/mingw/bin:/c/bin/git/bin:

# set the OPENMODELICAHOME and OPENMODELICALIBRARY
export OPENMODELICAHOME="c:\\OM19\\OpenModelica\\build"
export OPENMODELICALIBRARY="c:\\OM19\\OpenModelica\\build\\lib\\omlibrary"

# have OMDEV in Msys version
export OMDEV=/c/OM19/OMDev/

# update OMDev
cd /c/OM19/OMDev/
svn up . --accept theirs-full

# update OpenModelica
cd /c/OM19/OpenModelica
# delete the build directory
rm -rf build
git fetch && git fetch --tags
git reset --hard "$OPENMODELICA_BRANCH" && git checkout "$OPENMODELICA_BRANCH" && git fetch && git fetch --tags || exit 1
git checkout -f "$OPENMODELICA_BRANCH" || exit 1
git reset --hard "$OPENMODELICA_BRANCH" || exit 1
git submodule update --force --init --recursive || exit 1
git submodule foreach --recursive  "git fetch --tags && git reset --hard && git clean -fdxq -e /git -e /svn" || exit 1
git clean -fdxq -e OpenModelicaSetup || exit 1
git status
git submodule status --recursive


# get the revision
export REVISION=`git describe --match "v*.*" --always`
# Directory prefix
export OMC_INSTALL_PREFIX="/c/OM19/OpenModelica_releases/${REVISION}/"

# test if exists and exit if it does
if [ -d "${OMC_INSTALL_PREFIX}" ]; then
	echo "Revision ${OMC_INSTALL_PREFIX} already exists! Exiting ..."
	exit 0
fi

# create the revision directory
mkdir -p ${OMC_INSTALL_PREFIX}
# make the file prefix
export OMC_INSTALL_FILE_PREFIX="${OMC_INSTALL_PREFIX}OpenModelica-${REVISION}"

# update OpenModelicaSetup
cd /c/OM19/OpenModelica/OpenModelicaSetup
svn up . --accept theirs-full

# build OpenModelica
cd /c/OM19/OpenModelica
echo "Cleaning OpenModelica"
rm -rf build/
mkdir build/
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} clean
cd /c/OM19/OpenModelica
echo "Building OpenModelica"
make -f 'Makefile.omdev.mingw' ${MAKETHREADS}
echo "Building OpenModelica libraries"
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} omlibrary-all
cd /c/OM19/OpenModelica
echo "Installing Python scripting"
rm -rf OMPython
git clone https://github.com/OpenModelica/OMPython -q -b master /c/OM19/OpenModelica/OMPython
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} install-python
#build OMClients
echo "Cleaning OMClients"
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} clean-qtclients
echo "Building OMClients"
make -f 'Makefile.omdev.mingw' -j2 qtclients
cd /c/OM19/OpenModelica
echo "Building MSVC compiled runtime"
make -f 'Makefile.omdev.mingw' simulationruntimecmsvc
echo "Building MSVC CPP runtime"
make -f 'Makefile.omdev.mingw' BUILDTYPE=Release runtimeCPPmsvcinstall
echo "Building CPP runtime"
make -f 'Makefile.omdev.mingw' BUILDTYPE=Release runtimeCPPinstall

# wget the html & pdf versions of OpenModelica users guide
cd /c/OM19/OpenModelica/build/share/doc/omc
wget --no-check-certificate https://openmodelica.org/doc/openmodelica-doc-latest.tar.xz
tar -xJf openmodelica-doc-latest.tar.xz --strip-components=2
rm openmodelica-doc-latest.tar.xz
wget --no-check-certificate https://openmodelica.org/doc/OpenModelicaUsersGuide/OpenModelicaUsersGuide-latest.pdf

# get PySimulator
# for now get the master from github since OpenModelica plugin is still not part of tagged release. This should be updated once PySimulator outs a new release.
git clone https://github.com/PySimulator/PySimulator -q -b master /c/OM19/OpenModelica/build/share/omc/scripts/PythonInterface/PySimulator

# build the installer
cd /c/OM19/OpenModelica/OpenModelicaSetup
makensis OpenModelicaSetup.nsi > trace.txt 2>&1
cat trace.txt
# move the installer
mv OpenModelica.exe ${OMC_INSTALL_FILE_PREFIX}.exe

# gather the svn log
cd /c/OM19/OpenModelica
git log --name-status --graph --submodule > ${OMC_INSTALL_FILE_PREFIX}-ChangeLog.txt

# make the readme
export DATESTR=`date +"%Y-%m-%d_%H-%M"`
echo "Automatic build of OpenModelica by testwin.openmodelica.org at date: ${DATESTR} from revision: ${REVISION}" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo " " >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "Read OpenModelica-${REVISION}-ChangeLog.txt for more info on changes." >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo " " >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "See also (match revision ${REVISION} to build jobs):" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "  https://test.openmodelica.org/hudson/" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "  http://test.openmodelica.org/~marsj/MSL31/BuildModelRecursive.html" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "  http://test.openmodelica.org/~marsj/MSL32/BuildModelRecursive.html" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo " " >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
cat >> ${OMC_INSTALL_FILE_PREFIX}-README.txt <<DELIMITER
*Instructions to prepare test information if you find a bug:*
 
generate a .mos script file loading all libraries and files your model need call simulate.
// start .mos script
loadModel(Modelica);
loadFile("yourfile.mo");
simulate(YourModel);
// end .mos script

Start this .mos script in a shell with omc and use the debug flags
+d=dumpdaelow,optdaedump,bltdump,dumpindxdae,backenddaeinfo.
Redirect the output stream in file ( > log.txt)

A series of commands to run via cmd.exe
is given below. Note that z: is the drive
where your .mos script is:
c:\> z:
z:\> cd \path\to\script(.mos)\file\
z:\path\to\script(.mos)\file\> \path\to\OpenModelica\bin\omc.exe
+d=dumpdaelow,optdaedump,bltdump,dumpindxdae,backenddaeinfo 
YourScriptFile.mos > log.txt 2>&1

Either send the log.txt file alongwith your bug 
description to OpenModelica@ida.liu.se or file a
bug in our bug tracker:
  https://trac.openmodelica.org/OpenModelica

Happy testing!
DELIMITER
echo " " >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "Read more about OpenModelica at https://openmodelica.org" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "Contact us at OpenModelica@ida.liu.se for further issues or questions." >> ${OMC_INSTALL_FILE_PREFIX}-README.txt

# make the testsuite-trace
#cd /c/OM19/OpenModelica
#echo "Running testsuite trace"
#make -f 'Makefile.omdev.mingw' ${MAKETHREADS} testlogwindows > tmpTime.log 2>&1

echo "Check HUDSON testserver for the testsuite trace here (match revision ${REVISION} to build jobs): " >> ${OMC_INSTALL_FILE_PREFIX}-testsuite-trace.txt
echo "  https://test.openmodelica.org/hudson/" >> ${OMC_INSTALL_FILE_PREFIX}-testsuite-trace.txt
echo "  https://test.openmodelica.org/hudson/job/OM_Win/lastBuild/console" >> ${OMC_INSTALL_FILE_PREFIX}-testsuite-trace.txt
#cat tmpTime.log >> ${OMC_INSTALL_FILE_PREFIX}-testsuite-trace.txt
#rm -f tmpTime.log

ls -lah ${OMC_INSTALL_PREFIX}

cd ${OMC_INSTALL_PREFIX}
# move the last nightly build to the older location
ssh ${SSHUSER}@build.openmodelica.org <<ENDSSH
#commands to run on remote host
cd public_html/omc/builds/windows/releases/1.9maintenance/
mv -f OpenModelica* older/
ENDSSH
scp OpenModelica* ${SSHUSER}@build.openmodelica.org:public_html/omc/builds/windows/releases/1.9maintenance/
echo "All done!"
