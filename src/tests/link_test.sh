#\\macro <link_test.shpp>
#\\msg testing link() function
#\\define FRUITS/1=Apple
#\\link_test defines/FRUITS/1 defines/BASKET/1
#\\if @BASKET/1@ != Apple
#\\error Fehler
#\\endif
