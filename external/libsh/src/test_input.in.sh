test_input () { 
  DMSG_test_input_N=$(( $# + 1 ))
  DMSG_test_input_errmsg="$( read_farray "$err_input_messages" $DMSG_test_input_N)"
  if [ -n "$DMSG_test_input_errmsg" ] ; then
      d_msg ! 'wrong input' "$DMSG_test_input_errmsg"
      if [   $# = 0   ]; then
	return 1
      else
	  return 
      fi
  fi
}