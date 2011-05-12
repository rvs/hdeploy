#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function die() {
  echo $1
  exit 255
}

function bail() {
  echo $1
  exit 0
} 


USAGE="Usage: deploy-from-tar.sh <file-system-location> [zip URL]"

SELF=`dirname "${BASH_SOURCE-$0}"`
SELF=`cd "$bin"; pwd`

#. "$bin"/hdfs-config.sh

# get arguments
#if [ $# -ge 1 ]; then
#	nameStartOpt=$1
#	shift
#	case $nameStartOpt in
#	  (-upgrade)
#	  	;;
#	  (-rollback) 
#	  	dataStartOpt=$nameStartOpt
#	  	;;
#	  (*)
#		  echo $usage
#		  exit 1
#	    ;;
#	esac
#fi

WHERE=$1
TAR_URL=${2:-'https://builds.apache.org/hudson/view/G-L/view/Hadoop/job/Hadoop-22-Build/lastSuccessfulBuild/artifact/hadoop-0.22.0-SNAPSHOT.tar.gz'}

[ $# -lt 1  ] && die "$USAGE"
[ -d $WHERE ] || die "First argument $WHERE must be an existing directory" 

#
# Get the latest archive with all 3 artifacts (common, HDFS, mapreduce)
#
TMP="`mktemp /tmp/hdeploy.XXXXXXXXX`"
wget -O- "$TAR_URL" > $TMP || die "Couldn't fetch the latest artifact from $TAR_URL"

MD5="`md5sum $TMP | cut -f1 -d\  `"
[ -d $WHERE/$MD5 ] && bail "Latest artifact has already been deployed -- nothing to do"

mkdir $WHERE/$MD5
(cd $WHERE/$MD5 && tar xzf $TMP) || die "Can't unpack tarball"

mv $WHERE/$MD5/hadoop-0.22.0-SNAPSHOT/* $WHERE/$MD5
rmdir  $WHERE/$MD5/hadoop-0.22.0-SNAPSHOT

if [ -L $WHERE/hadoop-0.22.0 ]; then
 $WHERE/hadoop-0.22.0/bin/stop-mapred.sh
 $WHERE/hadoop-0.22.0/bin/stop-dfs.sh
 rm $WHERE/hadoop-0.22.0
fi

ln -s $WHERE/$MD5 $WHERE/hadoop-0.22.0

cp -r $SELF/../conf/* $WHERE/hadoop-0.22.0/conf || die "Can't move configs into $WHERE/hadoop-0.22.0/conf"

$WHERE/hadoop-0.22.0/bin/start-dfs.sh
$WHERE/hadoop-0.22.0/bin/start-mapred.sh
