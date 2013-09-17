test_input () { 
  LIBSH_test_input_N=$(( $# + 1 ))
  LIBSH_test_input_errmsg="$( read_farray "$err_input_messages" $LIBSH_test_input_N)"
  if [ -n "$LIBSH_test_input_errmsg" ] ; then
      d_msg ! 'wrong input' "$LIBSH_test_input_errmsg"
      if [   $# = 0   ]; then
	return 1
      else
	  return $LIBSH_test_input_N
      fi
  fi
}
