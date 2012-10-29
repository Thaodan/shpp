#
# Regular cron jobs for the sh-make-tools package
#
0 4	* * *	root	[ -x /usr/bin/sh-make-tools_maintenance ] && /usr/bin/sh-make-tools_maintenance
