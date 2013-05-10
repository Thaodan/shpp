#!/bin/sh
# this file contains functions functions that are 100% POSIX compatible
#
# Copyright (C) 2012  Björn Bidar
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

appname=`basename $0`
libsh_ver=@LIBSH_VER@
LIBSH_REV=@LIBSH_REV@



#\\include shload.in.sh
#########################################################################

#\\include d_msg.in.sh
#\\include farray.in.sh 
#\\include test_input.in.sh 

