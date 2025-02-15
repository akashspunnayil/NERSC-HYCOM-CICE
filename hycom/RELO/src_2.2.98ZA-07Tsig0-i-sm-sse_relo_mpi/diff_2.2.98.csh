#
set echo
#
#setenv C ~/hycom/RELO_GLB/src_2.2.98-09Tsig2-i_relo_mpi
setenv C ~/hycom/RELO_GLB/src_2.2.98ZA-09Tsig2-i_relo_mpi
#
foreach f ( Makefile Make.csh )
  echo "*****     *****     *****     *****     *****     *****     *****"
  diff -bw $f $C
end
foreach f ( *.h *.c )
  echo "*****     *****     *****     *****     *****     *****     *****"
  diff -ibw $f $C
end
#allow for possible switch from .f to .F or .F to .f
foreach f ( *.f *.F )
  echo "*****     *****     *****     *****     *****     *****     *****"
  diff -ibw $f $C/$f:r.[Ff]
end
